from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

import datetime
from django.utils import timezone

from django.http import HttpResponse, FileResponse, Http404
from .pdf_template_service import genera_pdf_ricevuta_da_template

from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule,
    SondaggioMattutinoConfig, GeminiLog, DocumentTemplate,
    ContatoreRicevute, Ricevuta, GoogleDriveConfig
)
from .serializers import (
    ScuolaSerializer, CorsoSerializer, ArgomentoSerializer,
    AllievoSerializer, JollySerializer, LezioneSerializer,
    PresenzaSerializer, PagamentoSerializer, MessageTemplateSerializer,
    MessageLogSerializer, MatchSerializer, RecurringScheduleSerializer,
    SondaggioMattutinoConfigSerializer, GeminiLogSerializer, DocumentTemplateSerializer,
    ContatoreRicevuteSerializer, RicevutaSerializer, GoogleDriveConfigSerializer
)
from .services import generate_matches
from .wa_client import send_whatsapp_message, get_whatsapp_status, get_group_participants, add_group_participant, resolve_group_link
from .tasks import (
    invia_sondaggio_manuale_corsi, invia_sondaggio_mattutino_giornaliero,
    invia_messaggio_sollecito, invia_sollecito_giornaliero
)



# ─── 2.1 Autenticazione Token per Client Flutter ────────────────

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def api_login(request):
    """
    Endpoint login per client Flutter.
    Riceve username e password, restituisce il token di autenticazione.
    """
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response(
            {'error': 'Username e password sono obbligatori.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    user = authenticate(username=username, password=password)
    if not user:
        return Response(
            {'error': 'Credenziali non valide.'},
            status=status.HTTP_401_UNAUTHORIZED
        )

    token, _ = Token.objects.get_or_create(user=user)
    return Response({
        'token': token.key,
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'is_superuser': user.is_superuser
        }
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def api_logout(request):
    """Invalida il token dell'utente corrente."""
    try:
        request.user.auth_token.delete()
    except Exception:
        pass
    return Response({'message': 'Logout effettuato con successo.'})


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def api_current_user(request):
    """Restituisce le informazioni dell'utente autenticato."""
    user = request.user
    return Response({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'is_superuser': user.is_superuser
    })


# ─── 2.3 ViewSets ───────────────────────────────────────────────

class ScuolaViewSet(viewsets.ModelViewSet):
    queryset = Scuola.objects.all()
    serializer_class = ScuolaSerializer
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ['nome', 'sede']
    ordering_fields = ['nome']

    @action(detail=True, methods=['get'], url_path='check-whatsapp')
    def check_whatsapp(self, request, pk=None):
        scuola = self.get_object()
        if not scuola.gruppo_whatsapp:
            return Response({'error': 'Nessun gruppo WhatsApp associato a questa scuola.'}, status=400)
            
        from .wa_client import get_group_participants
        wa_data = get_group_participants(scuola.gruppo_whatsapp)
        
        if not wa_data.get('success'):
            return Response({'error': f"Errore gateway WhatsApp: {wa_data.get('error', 'Sconosciuto')}"}, status=500)
            
        participants = wa_data.get('participants', [])
        
        wa_phones = []
        for p in participants:
            # Nuova API WhatsApp Node.js restituisce `phone` separato da `id` se `id` è in formato @lid
            phone = p.get('phone')
            if phone:
                wa_phones.append(phone)
            else:
                jid = p.get('id', '')
                if '@' in jid and not jid.endswith('@lid'):
                    num = jid.split('@')[0]
                    wa_phones.append(num)
                
        allievi = Allievo.objects.filter(is_active=True)
        db_phones_raw = list(allievi.values_list('telefono', flat=True))
        
        db_phones_set = set()
        for tel in db_phones_raw:
            if not tel: continue
            clean = ''.join(c for c in tel if c.isdigit())
            db_phones_set.add(clean)
            if not clean.startswith('39'):
                db_phones_set.add('39' + clean)
                
        unregistered = []
        for num in wa_phones:
            if num not in db_phones_set:
                unregistered.append(num)
                
        return Response({
            'total_participants': len(participants),
            'unregistered_count': len(unregistered),
            'unregistered_numbers': unregistered
        })


class CorsoViewSet(viewsets.ModelViewSet):
    queryset = Corso.objects.select_related('scuola').all()
    serializer_class = CorsoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['scuola', 'livello', 'anno_accademico']
    search_fields = ['scuola__nome', 'anno_accademico']
    ordering_fields = ['scuola__nome', 'livello', 'orario']


class ArgomentoViewSet(viewsets.ModelViewSet):
    queryset = Argomento.objects.all()
    serializer_class = ArgomentoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['livello']
    search_fields = ['titolo', 'descrizione']
    ordering_fields = ['titolo', 'livello']


class AllievoViewSet(viewsets.ModelViewSet):
    queryset = Allievo.objects.select_related('corso', 'corso__scuola').all()
    serializer_class = AllievoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = {
        'corso': ['exact', 'isnull'],
        'corso__scuola': ['exact'],
        'is_prospect': ['exact'],
        'ruolo': ['exact'],
        'livello': ['exact'],
        'recensione': ['exact'],
        'is_active': ['exact']
    }
    search_fields = ['nome', 'cognome', 'telefono', 'note', 'numero_tessera']
    ordering_fields = ['cognome', 'nome', 'livello', 'ruolo']

    def get_queryset(self):
        qs = super().get_queryset()
        stato_tessera = self.request.query_params.get('stato_tessera')
        if stato_tessera:
            from datetime import date, timedelta
            from django.db.models import Q
            one_year_ago = date.today() - timedelta(days=365)
            st = stato_tessera.lower().strip()
            if 'ok' in st:
                qs = qs.exclude(numero_tessera='').filter(
                    numero_tessera__isnull=False,
                    data_emissione_tessera__isnull=False,
                    data_emissione_tessera__gte=one_year_ago
                )
            elif 'scadut' in st:
                qs = qs.exclude(numero_tessera='').filter(
                    numero_tessera__isnull=False,
                    data_emissione_tessera__isnull=False,
                    data_emissione_tessera__lt=one_year_ago
                )
            elif 'non' in st or 'tesserato' in st:
                qs = qs.filter(
                    Q(numero_tessera='') | Q(numero_tessera__isnull=True) | Q(data_emissione_tessera__isnull=True)
                )
        return qs

    @action(detail=False, methods=['get'])
    def prospects(self, request):
        """Restituisce solo i prospect (non ancora iscritti a un corso)."""
        prospects = self.queryset.filter(is_prospect=True)
        serializer = self.get_serializer(prospects, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def convert_to_student(self, request, pk=None):
        """Converte un prospect in allievo effettivo assegnandogli un corso."""
        allievo = self.get_object()
        corso_id = request.data.get('corso_id')
        if not corso_id:
            return Response({'error': 'corso_id obbligatorio per la conversione.'}, status=status.HTTP_400_BAD_REQUEST)

        corso = Corso.objects.filter(id=corso_id).first()
        if not corso:
            return Response({'error': 'Corso non trovato.'}, status=status.HTTP_404_NOT_FOUND)

        allievo.corso = corso
        allievo.livello = corso.livello
        allievo.is_prospect = False
        allievo.save()
        return Response(self.get_serializer(allievo).data)

    @action(detail=True, methods=['post'])
    def set_partner(self, request, pk=None):
        """Imposta o rimuove il partner per un allievo in modo simmetrico."""
        allievo = self.get_object()
        partner_id = request.data.get('partner_id')
        
        # Se c'è già un partner, scollega la vecchia simmetria
        if allievo.partner:
            old_partner = allievo.partner
            old_partner.partner = None
            old_partner.save(update_fields=['partner'])
        # Rimuovi l'allievo dai vecchi partner che lo puntano (per sicurezza)
        Allievo.objects.filter(partner=allievo).update(partner=None)
        
        if partner_id:
            new_partner = Allievo.objects.filter(id=partner_id).first()
            if not new_partner:
                return Response({'error': 'Partner non trovato.'}, status=status.HTTP_404_NOT_FOUND)
            
            # Se il nuovo partner aveva già un partner, scollegalo
            if new_partner.partner:
                old_of_new = new_partner.partner
                old_of_new.partner = None
                old_of_new.save(update_fields=['partner'])
            Allievo.objects.filter(partner=new_partner).update(partner=None)
            
            # Crea la nuova simmetria
            allievo.partner = new_partner
            allievo.save(update_fields=['partner'])
            new_partner.partner = allievo
            new_partner.save(update_fields=['partner'])
            
            return Response(self.get_serializer(allievo).data)
        else:
            # Rimuove il partner
            allievo.partner = None
            allievo.save(update_fields=['partner'])
            return Response(self.get_serializer(allievo).data)

    @action(detail=False, methods=['post'], url_path='sync-whatsapp')
    def sync_whatsapp(self, request):
        return self._do_sync_whatsapp(request)

    @action(detail=False, methods=['post'], url_path='sync-whatsapp-scuola')
    def sync_whatsapp_scuola(self, request):
        return self._do_sync_whatsapp(request)

    def _do_sync_whatsapp(self, request):
        """
        Verifica per TUTTI gli allievi presenti a sistema se fanno parte del gruppo WhatsApp
        della scuola E del gruppo WhatsApp del corso, interrogando il Gateway WhatsApp
        e aggiorna sia in_gruppo_scuola_whatsapp che in_gruppo_corso_whatsapp nel database.
        """
        import re

        # 1. Controlla lo stato del gateway WhatsApp
        status_info = get_whatsapp_status()
        current_status = status_info.get('status')
        if current_status != 'CONNECTED':
            return Response({
                'error': f"Client WhatsApp non connesso (Stato attuale: {current_status}). "
                         "Accedi alla sezione WhatsApp per scansionare il QR code o connettere il client."
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        # 2. Scuole con gruppo WhatsApp impostato
        scuole = Scuola.objects.exclude(gruppo_whatsapp__isnull=True).exclude(gruppo_whatsapp__exact='')
        # Corsi con gruppo WhatsApp impostato
        corsi = Corso.objects.exclude(gruppo_whatsapp__isnull=True).exclude(gruppo_whatsapp__exact='')

        if not scuole.exists() and not corsi.exists():
            return Response({
                'error': "Nessuna scuola né corso ha un gruppo WhatsApp configurato a sistema."
            }, status=status.HTTP_400_BAD_REQUEST)

        def get_phone_keys(ph):
            if not ph:
                return set()
            d = re.sub(r'\D', '', str(ph))
            if not d:
                return set()
            keys = {d}
            if len(d) >= 9:
                keys.add(d[-9:])
            if len(d) >= 10:
                keys.add(d[-10:])
            if d.startswith('39') and len(d) > 2:
                keys.add(d[2:])
            elif len(d) == 10 and d.startswith('3'):
                keys.add('39' + d)
            return keys

        warnings = []

        # Recupera partecipanti per ogni scuola
        scuola_participants_map = {} # str(scuola.id) -> set of phone keys
        for s in scuole:
            group_jid = s.gruppo_whatsapp.strip()
            res = get_group_participants(group_jid)
            if res.get('success'):
                resolved = res.get('resolvedJid')
                if resolved and resolved != s.gruppo_whatsapp:
                    s.gruppo_whatsapp = resolved
                    s.save(update_fields=['gruppo_whatsapp'])

                participants = res.get('participants', [])
                group_keys = set()
                for p in participants:
                    p_phone = p.get('phone', '')
                    group_keys.update(get_phone_keys(p_phone))
                scuola_participants_map[str(s.id)] = group_keys
            else:
                warnings.append(f"Scuola '{s.nome}': {res.get('error', 'Errore sconosciuto')}")

        # Recupera partecipanti per ogni corso
        corso_participants_map = {} # str(corso.id) -> set of phone keys
        for c in corsi:
            group_jid = c.gruppo_whatsapp.strip()
            res = get_group_participants(group_jid)
            if res.get('success'):
                resolved = res.get('resolvedJid')
                if resolved and resolved != c.gruppo_whatsapp:
                    c.gruppo_whatsapp = resolved
                    c.save(update_fields=['gruppo_whatsapp'])

                participants = res.get('participants', [])
                group_keys = set()
                for p in participants:
                    p_phone = p.get('phone', '')
                    group_keys.update(get_phone_keys(p_phone))
                corso_participants_map[str(c.id)] = group_keys
            else:
                warnings.append(f"Corso '{c}': {res.get('error', 'Errore sconosciuto')}")

        # 3. Aggiorna TUTTI gli allievi presenti nel sistema (senza filtri)
        allievi = list(Allievo.objects.select_related('corso', 'corso__scuola').all())
        in_scuola_count = 0
        in_corso_count = 0
        to_update = []

        for a in allievi:
            # Controllo gruppo scuola
            new_scuola_val = False
            if a.corso and a.corso.scuola:
                scuola_id_str = str(a.corso.scuola.id)
                scuola_keys = scuola_participants_map.get(scuola_id_str)
                if scuola_keys:
                    student_keys = get_phone_keys(a.telefono)
                    if student_keys.intersection(scuola_keys):
                        new_scuola_val = True

            # Controllo gruppo corso
            new_corso_val = False
            if a.corso:
                corso_id_str = str(a.corso.id)
                corso_keys = corso_participants_map.get(corso_id_str)
                if corso_keys:
                    student_keys = get_phone_keys(a.telefono)
                    if student_keys.intersection(corso_keys):
                        new_corso_val = True

            a.in_gruppo_scuola_whatsapp = new_scuola_val
            a.in_gruppo_corso_whatsapp = new_corso_val
            to_update.append(a)

            if new_scuola_val:
                in_scuola_count += 1
            if new_corso_val:
                in_corso_count += 1

        if to_update:
            Allievo.objects.bulk_update(to_update, ['in_gruppo_scuola_whatsapp', 'in_gruppo_corso_whatsapp'])

        return Response({
            'success': True,
            'message': f"Controllo completato con successo su {len(allievi)} allievi.",
            'total_allievi': len(allievi),
            'in_gruppo_scuola': in_scuola_count,
            'non_in_gruppo_scuola': len(allievi) - in_scuola_count,
            'in_gruppo_corso': in_corso_count,
            'non_in_gruppo_corso': len(allievi) - in_corso_count,
            'scuole_verificate': len(scuola_participants_map),
            'corsi_verificati': len(corso_participants_map),
            'warnings': warnings
        })

    @action(detail=True, methods=['post'], url_path='add-to-whatsapp-scuola')
    def add_to_whatsapp_scuola(self, request, pk=None):
        """
        Aggiunge il singolo allievo al gruppo WhatsApp della scuola associata al suo corso.
        """
        allievo = self.get_object()

        if not allievo.telefono or allievo.telefono.strip().upper() == 'TBD':
            return Response(
                {'error': f"L'allievo {allievo.nome} {allievo.cognome} non ha un numero di telefono valido registrato."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not allievo.corso or not allievo.corso.scuola:
            return Response(
                {'error': f"L'allievo {allievo.nome} {allievo.cognome} non è assegnato a un corso con scuola associata."},
                status=status.HTTP_400_BAD_REQUEST
            )

        scuola = allievo.corso.scuola
        if not scuola.gruppo_whatsapp:
            return Response(
                {'error': f"La scuola '{scuola.nome}' non ha un gruppo WhatsApp configurato."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 1. Controlla lo stato del gateway WhatsApp
        status_info = get_whatsapp_status()
        if status_info.get('status') != 'CONNECTED':
            return Response({
                'error': f"Client WhatsApp non connesso (Stato attuale: {status_info.get('status')}). "
                         "Accedi alla sezione WhatsApp per verificare la connessione."
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        # 2. Richiedi aggiunta al gruppo tramite Gateway
        res = add_group_participant(scuola.gruppo_whatsapp, allievo.telefono)
        if res.get('success'):
            allievo.in_gruppo_scuola_whatsapp = True
            allievo.save(update_fields=['in_gruppo_scuola_whatsapp'])
            return Response({
                'success': True,
                'message': res.get('message', f"{allievo.nome} {allievo.cognome} aggiunto al gruppo '{scuola.nome}'!"),
                'allievo': self.get_serializer(allievo).data
            })
        else:
            return Response({
                'success': False,
                'error': res.get('error', "Impossibile aggiungere l'allievo al gruppo."),
                'invite_link': res.get('inviteLink')
            }, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'], url_path='add-to-whatsapp-corso')
    def add_to_whatsapp_corso(self, request, pk=None):
        """
        Aggiunge il singolo allievo al gruppo WhatsApp del corso a cui è iscritto.
        """
        allievo = self.get_object()

        if not allievo.telefono or allievo.telefono.strip().upper() == 'TBD':
            return Response(
                {'error': f"L'allievo {allievo.nome} {allievo.cognome} non ha un numero di telefono valido registrato."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not allievo.corso:
            return Response(
                {'error': f"L'allievo {allievo.nome} {allievo.cognome} non è assegnato ad alcun corso."},
                status=status.HTTP_400_BAD_REQUEST
            )

        corso = allievo.corso
        if not corso.gruppo_whatsapp:
            return Response(
                {'error': f"Il corso '{corso}' non ha un gruppo WhatsApp configurato."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 1. Controlla lo stato del gateway WhatsApp
        status_info = get_whatsapp_status()
        if status_info.get('status') != 'CONNECTED':
            return Response({
                'error': f"Client WhatsApp non connesso (Stato attuale: {status_info.get('status')}). "
                         "Accedi alla sezione WhatsApp per verificare la connessione."
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        # 2. Richiedi aggiunta al gruppo tramite Gateway
        res = add_group_participant(corso.gruppo_whatsapp, allievo.telefono)
        if res.get('success'):
            allievo.in_gruppo_corso_whatsapp = True
            allievo.save(update_fields=['in_gruppo_corso_whatsapp'])
            return Response({
                'success': True,
                'message': res.get('message', f"{allievo.nome} {allievo.cognome} aggiunto al gruppo del corso!"),
                'allievo': self.get_serializer(allievo).data
            })
        else:
            return Response({
                'success': False,
                'error': res.get('error', "Impossibile aggiungere l'allievo al gruppo del corso."),
                'invite_link': res.get('inviteLink')
            }, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'], url_path='invia-sollecito')
    def invia_sollecito(self, request, pk=None):
        """
        Invia un messaggio di sollecito risposta WhatsApp al singolo allievo o prospect.
        Utilizza il template configurato oppure il testo personalizzato passato nel body.
        """
        allievo = self.get_object()
        telefono = (allievo.telefono or '').strip()
        if not telefono:
            return Response(
                {'success': False, 'error': f"Nessun numero di telefono registrato per {allievo.nome} {allievo.cognome}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        testo = request.data.get('testo', '').strip()
        if not testo:
            cfg = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
            tmpl = cfg.sollecito_testo if (cfg and cfg.sollecito_testo) else "Ciao <nome_allievo>, ci sei stasera al corso?"
            testo = tmpl.replace('<nome_allievo>', allievo.nome)\
                        .replace('{allievo}', allievo.nome)\
                        .replace('{nome}', allievo.nome)\
                        .replace('<nome>', allievo.nome)

        res = send_whatsapp_message(
            to=telefono,
            message=testo,
            is_group=False
        )
        is_ok = bool(res.get('success'))
        return Response({
            'success': is_ok,
            'allievo_id': str(allievo.id),
            'allievo_nome': f"{allievo.nome} {allievo.cognome}",
            'telefono': telefono,
            'messaggio': testo,
            'error': res.get('error')
        })




class JollyViewSet(viewsets.ModelViewSet):
    queryset = Jolly.objects.select_related('allievo').order_by('priorita')
    serializer_class = JollySerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['priorita', 'allievo__ruolo', 'allievo__livello']
    ordering_fields = ['priorita']

    @action(detail=False, methods=['post'], url_path='send-message')
    def send_message(self, request):
        """
        API dedicata POST /api/jolly/send-message/
        Input:
          - testo: str (obbligatorio)
          - lezione_ids: list (opzionale, ID lezioni per cui servono i jolly)
          - jolly_ids: list (opzionale, ID specifici jolly da contattare)
          - num_jolly: int (opzionale, quanti jolly contattare in ordine di priorità)
        """
        return send_jolly_message(request)



class LezioneViewSet(viewsets.ModelViewSet):
    queryset = Lezione.objects.select_related('corso', 'corso__scuola', 'argomento').all()
    serializer_class = LezioneSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['corso', 'corso__scuola', 'data', 'argomento']
    search_fields = ['corso__scuola__nome', 'argomento__titolo']
    ordering_fields = ['data']

    @action(detail=True, methods=['get'])
    def presenze(self, request, pk=None):
        """Restituisce le presenze per la lezione selezionata, auto-inizializzando gli allievi mancanti."""
        lezione = self.get_object()
        
        # Auto-inizializzazione
        allievi = Allievo.objects.filter(corso=lezione.corso, is_active=True)
        for allievo in allievi:
            Presenza.objects.get_or_create(
                lezione=lezione,
                allievo=allievo,
                defaults={'presente': None, 'fonte': 'manuale'}
            )
            
        presenze = Presenza.objects.filter(lezione=lezione).select_related('allievo')
        serializer = PresenzaSerializer(presenze, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def init_presenze(self, request, pk=None):
        """Inizializza le presenze per tutti gli allievi."""
        lezione = self.get_object()
        allievi = Allievo.objects.filter(corso=lezione.corso, is_active=True)
        created_count = 0
        for allievo in allievi:
            _, created = Presenza.objects.get_or_create(
                lezione=lezione,
                allievo=allievo,
                defaults={'presente': None, 'fonte': 'manuale'}
            )
            if created:
                created_count += 1
        return Response({
            'message': f'Inizializzate {created_count} presenze per {allievi.count()} partecipanti del corso.'
        })

    @action(detail=True, methods=['post'], url_path='aggiungi-jolly')
    def aggiungi_jolly(self, request, pk=None):
        """Aggiunge un allievo (jolly) alle presenze della lezione e lo segna presente."""
        lezione = self.get_object()
        allievo_id = request.data.get('allievo_id')
        if not allievo_id:
            return Response({'error': 'allievo_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        allievo = Allievo.objects.filter(id=allievo_id).first()
        if not allievo:
            return Response({'error': 'Allievo non trovato.'}, status=status.HTTP_404_NOT_FOUND)

        presenza, created = Presenza.objects.update_or_create(
            lezione=lezione,
            allievo=allievo,
            defaults={'presente': True, 'fonte': 'manuale', 'is_jolly': True}
        )
        serializer = PresenzaSerializer(presenza)
        return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


    @action(detail=False, methods=['post'], url_path='crea-trimestre')
    def crea_trimestre(self, request):
        """
        Crea in blocco le lezioni per un trimestre.
        Body:
        {
            "corso": "corso_id",
            "lezioni": [
                {"data": "2025-10-06", "titolo": "1/12 - 1° Trimestre"},
                ...
            ]
        }
        """
        corso_id = request.data.get('corso')
        lezioni_data = request.data.get('lezioni', [])
        if not corso_id or not lezioni_data:
            return Response({'error': 'corso e lezioni sono obbligatori.'}, status=status.HTTP_400_BAD_REQUEST)

        corso = Corso.objects.filter(id=corso_id).first()
        if not corso:
            return Response({'error': 'Corso non trovato.'}, status=status.HTTP_404_NOT_FOUND)

        created = []
        for item in lezioni_data:
            lez = Lezione.objects.create(
                corso=corso,
                data=item['data'],
                titolo=item.get('titolo', ''),
                argomento_id=item.get('argomento')
            )
            created.append(lez)

        return Response(self.get_serializer(created, many=True).data, status=status.HTTP_201_CREATED)


class PresenzaViewSet(viewsets.ModelViewSet):
    queryset = Presenza.objects.select_related('lezione', 'allievo').all()
    serializer_class = PresenzaSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['lezione', 'allievo', 'presente', 'lezione__corso']
    ordering_fields = ['timestamp', 'allievo__cognome']

    @action(detail=False, methods=['post'])
    def batch_update(self, request):
        """
        Aggiornamento massivo presenze per una lezione.
        Riceve: { 'lezione_id': 'uuid', 'presenze': [{'allievo_id': 'uuid', 'presente': bool}] }
        """
        lezione_id = request.data.get('lezione_id')
        presenze_data = request.data.get('presenze', [])

        if not lezione_id:
            return Response({'error': 'lezione_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)

        lezione = Lezione.objects.filter(id=lezione_id).first()
        if not lezione:
            return Response({'error': 'Lezione non trovata.'}, status=status.HTTP_404_NOT_FOUND)

        updated_count = 0
        for item in presenze_data:
            allievo_id = item.get('allievo_id')
            presente_val = item.get('presente', False)
            fonte_val = item.get('fonte', 'manuale')
            if allievo_id:
                Presenza.objects.update_or_create(
                    lezione=lezione,
                    allievo_id=allievo_id,
                    defaults={'presente': presente_val, 'fonte': fonte_val}
                )
                updated_count += 1

        return Response({
            'success': True,
            'message': f'{updated_count} presenze salvate con successo.'
        })


class PagamentoViewSet(viewsets.ModelViewSet):
    queryset = Pagamento.objects.select_related('allievo', 'corso', 'corso__scuola').all()
    serializer_class = PagamentoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['allievo', 'corso', 'corso__scuola', 'trimestre']
    search_fields = ['allievo__nome', 'allievo__cognome', 'corso__scuola__nome', 'causale', 'note']
    ordering_fields = ['data_pagamento', 'importo']

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Restituisce il PDF della ricevuta compilato dal template per il pagamento specificato."""
        pagamento = self.get_object()
        try:
            allievo_nome = f"{pagamento.allievo.nome} {pagamento.allievo.cognome}" if pagamento.allievo else "Ricevuta"
            numero = str(pagamento.id)[:6].upper()
            anno = pagamento.data_pagamento.year if pagamento.data_pagamento else timezone.now().year
            causale = pagamento.causale
            if not causale:
                causale = f"Quota corso {pagamento.corso.nome if pagamento.corso else ''}"
                if pagamento.trimestre:
                    causale += f" ({pagamento.get_trimestre_display()})"

            pdf_bytes = genera_pdf_ricevuta_da_template(
                numero=numero,
                anno=anno,
                intestatario=allievo_nome,
                importo=pagamento.importo,
                causale=causale,
                data_emissione=pagamento.data_pagamento or timezone.now().date()
            )
            if not pdf_bytes:
                return Response({'error': 'Template ricevuta non trovato o non configurato.'}, status=status.HTTP_404_NOT_FOUND)

            filename = f"ricevuta_pagamento_{pagamento.id}.pdf"
            response = HttpResponse(pdf_bytes, content_type='application/pdf')
            response['Content-Disposition'] = f'inline; filename="{filename}"'
            return response
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MessageTemplateViewSet(viewsets.ModelViewSet):
    queryset = MessageTemplate.objects.all()
    serializer_class = MessageTemplateSerializer


class MessageLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = MessageLog.objects.select_related('lezione', 'template').all().order_by('-timestamp')
    serializer_class = MessageLogSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['lezione', 'status']


class MatchViewSet(viewsets.ModelViewSet):
    queryset = Match.objects.select_related('lezione', 'leader', 'follower').all()
    serializer_class = MatchSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['lezione', 'is_rotation']

    @action(detail=False, methods=['post'])
    def generate(self, request):
        """Genera le coppie per una data lezione tra gli allievi con presenza=True."""
        lezione_id = request.data.get('lezione_id')
        if not lezione_id:
            return Response({'error': 'lezione_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)

        lezione = Lezione.objects.filter(id=lezione_id).first()
        if not lezione:
            return Response({'error': 'Lezione non trovata.'}, status=status.HTTP_404_NOT_FOUND)

        stats = generate_matches(lezione.id)
        matches = Match.objects.filter(lezione=lezione).select_related('leader', 'follower')
        serializer = self.get_serializer(matches, many=True)
        return Response({
            'stats': stats,
            'matches': serializer.data
        })


class RecurringScheduleViewSet(viewsets.ModelViewSet):
    queryset = RecurringSchedule.objects.select_related('corso').all()
    serializer_class = RecurringScheduleSerializer


# ─── 2.4 Endpoint Invio Messaggi Jolly ──────────────────────────

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def send_jolly_message(request):
    """
    API dedicata POST /api/jolly/send-message/
    Input:
      - testo: str (obbligatorio)
      - lezione_ids: list (opzionale, ID lezioni per cui servono i jolly)
      - jolly_ids: list (opzionale, ID specifici jolly da contattare)
      - num_jolly: int (opzionale, quanti jolly contattare in ordine di priorità)
    """
    testo = request.data.get('testo', '').strip()
    lezione_ids = request.data.get('lezione_ids', [])
    jolly_ids = request.data.get('jolly_ids', [])
    num_jolly = request.data.get('num_jolly', 0)

    if not testo:
        return Response(
            {'error': 'Il testo del messaggio è obbligatorio.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Selezione dei jolly
    if jolly_ids:
        jolly_list = list(Jolly.objects.filter(id__in=jolly_ids).select_related('allievo'))
    elif num_jolly and int(num_jolly) > 0:
        jolly_list = list(Jolly.objects.order_by('priorita').select_related('allievo')[:int(num_jolly)])
    else:
        # Se non specificato, invia a tutti i jolly ordinati per priorità
        jolly_list = list(Jolly.objects.order_by('priorita').select_related('allievo'))

    if not jolly_list:
        return Response(
            {'error': 'Nessun jolly trovato con i criteri specificati.'},
            status=status.HTTP_404_NOT_FOUND
        )

    # Costruisci testo info lezioni se fornite
    lezioni_info = ""
    if lezione_ids:
        lezioni = Lezione.objects.filter(id__in=lezione_ids).select_related('corso', 'corso__scuola', 'argomento')
        righe = []
        for lez in lezioni:
            arg = f" - {lez.argomento.titolo}" if lez.argomento else ""
            righe.append(f"📅 {lez.data.strftime('%d/%m/%Y')} {lez.corso.orario.strftime('%H:%M')} | {lez.corso.scuola.nome} - {lez.corso.get_livello_display()}{arg}")
        if righe:
            lezioni_info = "\n\nLezioni in cui servono jolly:\n" + "\n".join(righe)

    messaggio_finale = testo + lezioni_info

    results = []
    success_count = 0
    for jolly in jolly_list:
        allievo = jolly.allievo
        res = send_whatsapp_message(
            to=allievo.telefono,
            message=messaggio_finale,
            is_group=False
        )
        is_ok = bool(res.get('success'))
        if is_ok:
            success_count += 1
        results.append({
            'jolly_id': str(jolly.id),
            'allievo_nome': f"{allievo.nome} {allievo.cognome}",
            'telefono': allievo.telefono,
            'priorita': jolly.priorita,
            'success': is_ok,
            'error': res.get('error')
        })

    return Response({
        'success': True,
        'totale_contattati': len(results),
        'inviati_con_successo': success_count,
        'dettagli': results
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def api_resolve_whatsapp_group(request):
    """
    Risolve un link di invito o codice WhatsApp nel JID reale e metadati del gruppo.
    """
    link = request.data.get('link') or request.data.get('input') or ''
    if not link:
        return Response(
            {'success': False, 'error': "Link d'invito o codice WhatsApp mancante."},
            status=status.HTTP_400_BAD_REQUEST
        )
    res = resolve_group_link(link)
    if res.get('success'):
        return Response(res, status=status.HTTP_200_OK)
    else:
        return Response(res, status=status.HTTP_400_BAD_REQUEST)


def sync_daemon_schedule(orario_str):
    """
    Sincronizza o aggiorna l'orario del task pianificato in Django-Q
    in base alla configurazione impostata dall'utente.
    """
    try:
        from django_q.models import Schedule
        parts = (orario_str or '08:00').split(':')
        hour = int(parts[0])
        minute = int(parts[1]) if len(parts) > 1 else 0

        now = timezone.localtime(timezone.now())
        target_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if target_time <= now:
            target_time += datetime.timedelta(days=1)

        sched = Schedule.objects.filter(func='core.tasks.invia_sondaggio_mattutino_giornaliero').first()
        if sched:
            sched.next_run = target_time
            sched.save()
        else:
            Schedule.objects.create(
                name='Sondaggio Mattutino Giornaliero',
                func='core.tasks.invia_sondaggio_mattutino_giornaliero',
                schedule_type=Schedule.DAILY,
                next_run=target_time
            )
    except Exception as e:
        print(f"Errore sincronizzazione schedule Django-Q: {e}")


def sync_sollecito_schedule(sollecito_orario_str, attivo=True):
    """
    Sincronizza o aggiorna l'orario del task pianificato per il sollecito pomeridiano in Django-Q.
    """
    try:
        from django_q.models import Schedule
        sched = Schedule.objects.filter(func='core.tasks.invia_sollecito_giornaliero').first()
        if not attivo:
            if sched:
                sched.delete()
            return

        parts = (sollecito_orario_str or '16:00').split(':')
        hour = int(parts[0])
        minute = int(parts[1]) if len(parts) > 1 else 0

        now = timezone.localtime(timezone.now())
        target_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if target_time <= now:
            target_time += datetime.timedelta(days=1)

        if sched:
            sched.next_run = target_time
            sched.save()
        else:
            Schedule.objects.create(
                name='Sollecito Presenze Giornaliero',
                func='core.tasks.invia_sollecito_giornaliero',
                schedule_type=Schedule.DAILY,
                next_run=target_time
            )
    except Exception as e:
        print(f"Errore sincronizzazione sollecito Django-Q: {e}")


class SondaggioMattutinoViewSet(viewsets.ModelViewSet):
    """
    CRUD configurazione sondaggio mattutino, impostazione orario/giorni demone, sollecito e invio manuale.
    """
    queryset = SondaggioMattutinoConfig.objects.all().select_related('corso', 'corso__scuola')
    serializer_class = SondaggioMattutinoConfigSerializer
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get', 'post'], url_path='daemon-config')
    def daemon_config(self, request):
        config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
        if not config:
            config = SondaggioMattutinoConfig.objects.create(
                corso=None,
                orario='08:00',
                giorni_settimana='0,1,2,3,4,5,6',
                testo="Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\nChi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!",
                is_poll=True,
                poll_opzione_1="Ci sono! 🕺💃",
                poll_opzione_2="Non ci sono 🚫",
                is_active=True,
                sollecito_attivo=False,
                sollecito_orario='16:00'
            )

        if request.method == 'POST':
            data = request.data
            if 'orario' in data:
                config.orario = data['orario']
            if 'giorni_settimana' in data:
                config.giorni_settimana = data['giorni_settimana']
            if 'testo' in data:
                config.testo = data['testo']
            if 'is_poll' in data:
                config.is_poll = bool(data['is_poll'])
            if 'poll_opzione_1' in data:
                config.poll_opzione_1 = data['poll_opzione_1']
            if 'poll_opzione_2' in data:
                config.poll_opzione_2 = data['poll_opzione_2']
            if 'is_active' in data:
                config.is_active = bool(data['is_active'])
            if 'sollecito_attivo' in data:
                config.sollecito_attivo = bool(data['sollecito_attivo'])
            if 'sollecito_orario' in data:
                config.sollecito_orario = data['sollecito_orario']
            if 'sollecito_testo' in data:
                config.sollecito_testo = data['sollecito_testo']

            config.save()
            sync_daemon_schedule(config.orario)
            sync_sollecito_schedule(config.sollecito_orario, config.sollecito_attivo)

        serializer = self.get_serializer(config)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='invia-manuale')
    def invia_manuale(self, request):
        corso_ids = request.data.get('corso_ids', [])
        testo = request.data.get('testo', '')
        is_poll = request.data.get('is_poll', True)
        poll_opzioni = request.data.get('poll_opzioni', None)

        if not corso_ids:
            return Response(
                {'success': False, 'error': "Seleziona almeno un corso a cui inviare il sondaggio."},
                status=status.HTTP_400_BAD_REQUEST
            )

        results = invia_sondaggio_manuale_corsi(
            corso_ids=corso_ids,
            testo_custom=testo,
            is_poll=is_poll,
            poll_opzioni=poll_opzioni
        )

        success_count = sum(1 for r in results if r.get('success'))
        return Response({
            'success': True,
            'totale_corsi': len(results),
            'inviati_con_successo': success_count,
            'dettagli': results
        })

    @action(detail=False, methods=['post'], url_path='esegui-demone-ora')
    def esegui_demone_ora(self, request):
        """Esegue immediatamente il controllo del demone per oggi."""
        try:
            invia_sondaggio_mattutino_giornaliero()
            return Response({'success': True, 'message': 'Esecuzione demone avviata con successo.'})
        except Exception as e:
            return Response({'success': False, 'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='invia-sollecito-ora')
    def invia_sollecito_ora(self, request):
        """Invia immediatamente il messaggio di sollecito per oggi o per i corsi selezionati."""
        try:
            corso_ids = request.data.get('corso_ids', None)
            res = invia_messaggio_sollecito(corso_ids=corso_ids)
            return Response(res)
        except Exception as e:
            return Response({'success': False, 'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class GeminiLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = GeminiLog.objects.all().order_by('-timestamp')
    serializer_class = GeminiLogSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['esito_interpretato', 'allievo', 'lezione']
    ordering_fields = ['timestamp']


class DocumentTemplateViewSet(viewsets.ModelViewSet):
    queryset = DocumentTemplate.objects.all()
    serializer_class = DocumentTemplateSerializer
    lookup_field = 'chiave'

    def list(self, request, *args, **kwargs):
        # Assicura che i template predefiniti esistano
        predefiniti = [
            ('ricevuta', 'Template Ricevuta Pagamento', 'Template PDF utilizzato per la generazione delle ricevute di pagamento quote e corsi.'),
            ('modulo_tesseramento', 'Modulo di Tesseramento', 'Modulo PDF ufficiale per la richiesta o rinnovo del tesseramento degli allievi.')
        ]
        for chiave, nome, desc in predefiniti:
            DocumentTemplate.objects.get_or_create(
                chiave=chiave,
                defaults={'nome': nome, 'descrizione': desc}
            )
        return super().list(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='upload')
    def upload_file(self, request, chiave=None):
        template = self.get_object()
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'success': False, 'error': 'Nessun file fornito.'}, status=status.HTTP_400_BAD_REQUEST)

        # Se esiste già un file, rimuovilo prima dal disco
        if template.file:
            try:
                template.file.delete(save=False)
            except Exception:
                pass

        template.file = file_obj
        template.save()

        serializer = self.get_serializer(template)
        return Response({'success': True, 'template': serializer.data})

    @action(detail=True, methods=['post', 'delete'], url_path='remove')
    def remove_file(self, request, chiave=None):
        template = self.get_object()
        if template.file:
            try:
                template.file.delete(save=False)
            except Exception:
                pass
            template.file = None
            template.save()

        serializer = self.get_serializer(template)
        return Response({'success': True, 'template': serializer.data})

    @action(detail=True, methods=['get'], url_path='file', permission_classes=[permissions.AllowAny])
    def download_file(self, request, chiave=None):
        template = self.get_object()
        if not template.file:
            raise Http404("Nessun file associato a questo template.")
        try:
            return FileResponse(template.file.open('rb'), content_type='application/pdf', filename=template.filename)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)


class RicevutaViewSet(viewsets.ModelViewSet):
    queryset = Ricevuta.objects.all().order_by('-anno', '-numero')
    serializer_class = RicevutaSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['anno', 'allievo']
    ordering_fields = ['numero', 'anno', 'data', 'importo', 'created_at']

    def get_queryset(self):
        qs = super().get_queryset()
        anno = self.request.query_params.get('anno')
        if anno:
            try:
                qs = qs.filter(anno=int(anno))
            except ValueError:
                pass
        search = self.request.query_params.get('search')
        if search:
            from django.db.models import Q
            qs = qs.filter(
                Q(intestatario__icontains=search) |
                Q(causale__icontains=search) |
                Q(note__icontains=search) |
                Q(numero__icontains=search)
            )
        return qs

    def perform_create(self, serializer):
        serializer.save()

    @action(detail=False, methods=['get'], url_path='anni')
    def get_anni(self, request):
        """Restituisce l'elenco degli anni per cui esistono ricevute, includendo l'anno corrente."""
        curr_year = timezone.now().year
        anni_db = list(Ricevuta.objects.values_list('anno', flat=True).distinct())
        anni_cont = list(ContatoreRicevute.objects.values_list('anno', flat=True).distinct())
        tutti_anni = sorted(list(set(anni_db + anni_cont + [curr_year])), reverse=True)
        return Response({'anni': tutti_anni, 'anno_corrente': curr_year})

    @action(detail=False, methods=['get'], url_path='contatore')
    def get_contatore(self, request):
        """Restituisce il contatore di ricevute per l'anno specificato (default anno corrente)."""
        anno_param = request.query_params.get('anno')
        curr_year = timezone.now().year
        try:
            anno = int(anno_param) if anno_param else curr_year
        except ValueError:
            anno = curr_year

        contatore, created = ContatoreRicevute.objects.get_or_create(
            anno=anno,
            defaults={'ultimo_numero': 0}
        )
        if created:
            from django.db.models import Max
            max_existing = Ricevuta.objects.filter(anno=anno).aggregate(m=Max('numero'))['m'] or 0
            if max_existing > 0:
                contatore.ultimo_numero = max_existing
                contatore.save()

        conteggio_emesse = Ricevuta.objects.filter(anno=anno).count()

        return Response({
            'anno': anno,
            'ultimo_numero': contatore.ultimo_numero,
            'prossimo_numero': contatore.ultimo_numero + 1,
            'conteggio_emesse': conteggio_emesse,
            'is_anno_corrente': (anno == curr_year),
        })

    @action(detail=False, methods=['post'], url_path='aggiorna-contatore')
    def aggiorna_contatore(self, request):
        """Permette di modificare il contatore (ultimo_numero) per un anno specificato."""
        anno = request.data.get('anno')
        ultimo_numero = request.data.get('ultimo_numero')

        curr_year = timezone.now().year
        try:
            anno = int(anno) if anno is not None else curr_year
        except ValueError:
            anno = curr_year

        if ultimo_numero is None:
            return Response({'error': 'Campo ultimo_numero obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            ultimo_numero = int(ultimo_numero)
            if ultimo_numero < 0:
                return Response({'error': 'Il numero deve essere maggiore o uguale a 0.'}, status=status.HTTP_400_BAD_REQUEST)
        except ValueError:
            return Response({'error': 'Valore ultimo_numero non valido.'}, status=status.HTTP_400_BAD_REQUEST)

        contatore, _ = ContatoreRicevute.objects.get_or_create(
            anno=anno,
            defaults={'ultimo_numero': ultimo_numero}
        )
        contatore.ultimo_numero = ultimo_numero
        contatore.save()

        conteggio_emesse = Ricevuta.objects.filter(anno=anno).count()
        return Response({
            'success': True,
            'anno': anno,
            'ultimo_numero': contatore.ultimo_numero,
            'prossimo_numero': contatore.ultimo_numero + 1,
            'conteggio_emesse': conteggio_emesse,
        })

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Restituisce il PDF compilato dal template per la ricevuta specificata."""
        ricevuta = self.get_object()
        try:
            pdf_bytes = genera_pdf_ricevuta_da_template(
                numero=ricevuta.numero,
                anno=ricevuta.anno,
                intestatario=ricevuta.intestatario,
                importo=ricevuta.importo,
                causale=ricevuta.causale,
                data_emissione=ricevuta.data
            )
            if not pdf_bytes:
                return Response({'error': 'Template ricevuta non trovato o non configurato.'}, status=status.HTTP_404_NOT_FOUND)

            filename = f"ricevuta_{ricevuta.numero}_{ricevuta.anno}.pdf"
            response = HttpResponse(pdf_bytes, content_type='application/pdf')
            response['Content-Disposition'] = f'inline; filename="{filename}"'
            return response
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class GoogleDriveConfigViewSet(viewsets.ViewSet):
    """
    Gestione della configurazione e chiave privata Google Drive.
    """
    def list(self, request):
        config = GoogleDriveConfig.get_instance()
        serializer = GoogleDriveConfigSerializer(config)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='upload')
    def upload_file(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'success': False, 'error': 'Nessun file fornito.'}, status=status.HTTP_400_BAD_REQUEST)

        config = GoogleDriveConfig.get_instance()

        content_bytes = file_obj.read()
        file_obj.seek(0)

        client_email = ''
        project_id = ''
        private_key_id = ''

        try:
            import json
            data = json.loads(content_bytes.decode('utf-8'))
            if isinstance(data, dict):
                client_email = data.get('client_email', '')
                project_id = data.get('project_id', '')
                private_key_id = data.get('private_key_id', '')
        except Exception:
            pass

        if config.credentials_file:
            try:
                config.credentials_file.delete(save=False)
            except Exception:
                pass

        config.credentials_file = file_obj
        config.client_email = client_email
        config.project_id = project_id
        config.private_key_id = private_key_id
        config.last_test_status = ''
        config.last_test_message = ''
        config.last_tested_at = None
        config.save()

        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['post'], url_path='test')
    def test_connection(self, request):
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Nessuna chiave privata caricata per Google Drive.'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            from google.oauth2 import service_account
            from googleapiclient.discovery import build

            credentials = service_account.Credentials.from_service_account_file(
                config.credentials_file.path,
                scopes=['https://www.googleapis.com/auth/drive']
            )
            drive_service = build('drive', 'v3', credentials=credentials)

            about = drive_service.about().get(fields='user').execute()
            user_info = about.get('user', {})
            user_display = user_info.get('displayName') or user_info.get('emailAddress') or config.client_email or 'Google Drive'

            config.last_test_status = 'success'
            config.last_test_message = f"Connessione a Google Drive riuscita! Account: {user_display}"
            config.last_tested_at = timezone.now()
            config.save()

            serializer = GoogleDriveConfigSerializer(config)
            return Response({'success': True, 'config': serializer.data, 'message': config.last_test_message})
        except Exception as e:
            config.last_test_status = 'error'
            config.last_test_message = f"Errore connessione Google Drive: {str(e)}"
            config.last_tested_at = timezone.now()
            config.save()

            serializer = GoogleDriveConfigSerializer(config)
            return Response({'success': False, 'config': serializer.data, 'error': config.last_test_message})

    @action(detail=False, methods=['post', 'delete'], url_path='remove')
    def remove_file(self, request):
        config = GoogleDriveConfig.get_instance()
        if config.credentials_file:
            try:
                config.credentials_file.delete(save=False)
            except Exception:
                pass
            config.credentials_file = None
            config.client_email = ''
            config.project_id = ''
            config.private_key_id = ''
            config.last_test_status = ''
            config.last_test_message = ''
            config.last_tested_at = None
            config.save()

        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    def _get_drive_service(self, config=None):
        if not config:
            config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            raise ValueError('Nessuna chiave privata valida configurata per Google Drive.')
        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        credentials = service_account.Credentials.from_service_account_file(
            config.credentials_file.path,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        return build('drive', 'v3', credentials=credentials)

    @action(detail=False, methods=['get'], url_path='folders')
    def list_folders(self, request):
        """
        Sfoglia l'alberatura delle cartelle di Google Drive a cui ha accesso il service account.
        Se parent_id è vuoto o 'root', elenca le cartelle condivise direttamente con il service account,
        le cartelle radice del suo drive e gli Shared Drives (Team Drives).
        Se parent_id è specificato, elenca le sottocartelle di quel parent.
        """
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Nessuna chiave privata configurata per Google Drive. Carica prima il file delle credenziali.'
            }, status=status.HTTP_400_BAD_REQUEST)

        parent_id = (request.query_params.get('parent_id') or '').strip()

        try:
            drive_service = self._get_drive_service(config)

            if not parent_id or parent_id == 'root':
                # Radice / Cartelle condivise con il Service Account
                items_dict = {}

                # 1. Cartelle condivise con il service account
                try:
                    q_shared = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and sharedWithMe = true"
                    res_shared = drive_service.files().list(
                        q=q_shared,
                        pageSize=100,
                        fields='files(id, name, mimeType, parents, owners, modifiedTime)',
                        supportsAllDrives=True,
                        includeItemsFromAllDrives=True
                    ).execute()
                    for f in res_shared.get('files', []):
                        items_dict[f['id']] = {
                            'id': f['id'],
                            'name': f.get('name', 'Senza nome'),
                            'is_shared': True,
                            'parents': f.get('parents', []),
                        }
                except Exception as e:
                    print(f"Avviso cartelle sharedWithMe: {e}")

                # 2. Cartelle radice del Drive del Service Account
                try:
                    q_root = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and 'root' in parents"
                    res_root = drive_service.files().list(
                        q=q_root,
                        pageSize=100,
                        fields='files(id, name, mimeType, parents, owners, modifiedTime)',
                        supportsAllDrives=True,
                        includeItemsFromAllDrives=True
                    ).execute()
                    for f in res_root.get('files', []):
                        items_dict[f['id']] = {
                            'id': f['id'],
                            'name': f.get('name', 'Senza nome'),
                            'is_shared': False,
                            'parents': f.get('parents', []),
                        }
                except Exception as e:
                    print(f"Avviso cartelle root: {e}")

                # 3. Shared Drives (Team Drives)
                try:
                    res_drives = drive_service.drives().list(pageSize=50).execute()
                    for d in res_drives.get('drives', []):
                        items_dict[d['id']] = {
                            'id': d['id'],
                            'name': d.get('name', 'Shared Drive'),
                            'is_drive': True,
                            'parents': [],
                        }
                except Exception:
                    pass

                folders = sorted(items_dict.values(), key=lambda x: x['name'].lower())
                return Response({
                    'success': True,
                    'parent_id': 'root',
                    'current_folder': {
                        'id': 'root',
                        'name': 'Radice / Cartelle Condivise',
                        'parents': [],
                    },
                    'breadcrumbs': [
                        {'id': 'root', 'name': 'Drive (Radice / Condivisi)'}
                    ],
                    'folders': folders
                })
            else:
                # Sottocartella specifica
                current_info = {'id': parent_id, 'name': parent_id, 'parents': []}
                try:
                    current_info = drive_service.files().get(
                        fileId=parent_id,
                        fields='id, name, parents',
                        supportsAllDrives=True
                    ).execute()
                except Exception:
                    pass

                q_sub = f"mimeType = 'application/vnd.google-apps.folder' and trashed = false and '{parent_id}' in parents"
                res_sub = drive_service.files().list(
                    q=q_sub,
                    pageSize=100,
                    fields='files(id, name, mimeType, parents, modifiedTime)',
                    supportsAllDrives=True,
                    includeItemsFromAllDrives=True
                ).execute()

                subfolders = []
                for f in res_sub.get('files', []):
                    subfolders.append({
                        'id': f['id'],
                        'name': f.get('name', 'Senza nome'),
                        'parents': f.get('parents', []),
                    })
                subfolders.sort(key=lambda x: x['name'].lower())

                return Response({
                    'success': True,
                    'parent_id': parent_id,
                    'current_folder': current_info,
                    'folders': subfolders
                })

        except Exception as e:
            return Response({
                'success': False,
                'error': f"Errore durante l'accesso alle cartelle di Google Drive: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='create-folder')
    def create_folder(self, request):
        """
        Crea una nuova cartella su Google Drive all'interno della cartella specificata.
        """
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Google Drive non configurato.'
            }, status=status.HTTP_400_BAD_REQUEST)

        name = (request.data.get('name') or '').strip()
        parent_id = (request.data.get('parent_id') or '').strip()

        if not name:
            return Response({'success': False, 'error': 'Nome della cartella obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            drive_service = self._get_drive_service(config)
            body = {
                'name': name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            if parent_id and parent_id != 'root':
                body['parents'] = [parent_id]

            new_folder = drive_service.files().create(
                body=body,
                fields='id, name, parents',
                supportsAllDrives=True
            ).execute()

            return Response({
                'success': True,
                'folder': {
                    'id': new_folder.get('id'),
                    'name': new_folder.get('name'),
                    'parents': new_folder.get('parents', [])
                }
            })
        except Exception as e:
            return Response({
                'success': False,
                'error': f"Errore creazione cartella: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['patch', 'post'], url_path='update-settings')
    def update_settings(self, request):
        config = GoogleDriveConfig.get_instance()
        folder_fields = [
            'folder_id',
            'folder_ricevute_id',
            'folder_ricevute_nome',
            'folder_tessere_id',
            'folder_tessere_nome'
        ]
        for f in folder_fields:
            if f in request.data:
                setattr(config, f, str(request.data.get(f) or '').strip())

        if 'is_active' in request.data:
            config.is_active = bool(request.data.get('is_active'))

        config.save()
        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})


