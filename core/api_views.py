from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

import os
import datetime
from django.utils import timezone
from django.db import transaction

from django.http import HttpResponse, FileResponse, Http404
from .pdf_template_service import genera_pdf_ricevuta_da_template, genera_pdf_modulo_tesseramento

from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule,
    SondaggioMattutinoConfig, GeminiLog, DocumentTemplate,
    ContatoreRicevute, Ricevuta, GoogleDriveConfig, GoogleContactsConfig, MovimentoPrimaNota, CategoriaBilancio,
    ConfigurazioneASD, MembroDirettivo
)
from .serializers import (
    ScuolaSerializer, CorsoSerializer, ArgomentoSerializer,
    AllievoSerializer, JollySerializer, LezioneSerializer,
    PresenzaSerializer, PagamentoSerializer, MessageTemplateSerializer,
    MessageLogSerializer, MatchSerializer, RecurringScheduleSerializer,
    SondaggioMattutinoConfigSerializer, GeminiLogSerializer, DocumentTemplateSerializer,
    ContatoreRicevuteSerializer, RicevutaSerializer, GoogleDriveConfigSerializer, GoogleContactsConfigSerializer,
    MovimentoPrimaNotaSerializer, CategoriaBilancioSerializer,
    ConfigurazioneASDSerializer, MembroDirettivoSerializer
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
    queryset = Argomento.objects.all().order_by('ordine', 'titolo')
    serializer_class = ArgomentoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['livello']
    search_fields = ['titolo', 'descrizione']
    ordering_fields = ['ordine', 'titolo', 'livello']
    ordering = ['ordine', 'titolo']

    @action(detail=False, methods=['post'])
    def reorder(self, request):
        """
        Aggiorna l'ordinamento degli argomenti tramite drag & drop.
        Accetta {'ids': ['id1', 'id2', ...]} oppure {'items': [{'id': 'id1', 'ordine': 0}, ...]}
        """
        ids = request.data.get('ids')
        items = request.data.get('items')

        with transaction.atomic():
            if isinstance(ids, list):
                for index, item_id in enumerate(ids):
                    Argomento.objects.filter(id=item_id).update(ordine=index)
            elif isinstance(items, list):
                for item in items:
                    item_id = item.get('id')
                    ordine = item.get('ordine', 0)
                    if item_id:
                        Argomento.objects.filter(id=item_id).update(ordine=ordine)
            else:
                return Response({'error': 'Parametro ids o items mancante o non valido'}, status=status.HTTP_400_BAD_REQUEST)

        updated = Argomento.objects.all().order_by('ordine', 'titolo')
        serializer = self.get_serializer(updated, many=True)
        return Response(serializer.data)


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

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        allievo = serializer.save()
        google_sync = None
        try:
            from .google_contacts_service import sync_allievo_to_google_contacts
            google_sync = sync_allievo_to_google_contacts(allievo)
        except Exception as e:
            google_sync = {'success': False, 'error': str(e)}

        data = serializer.data
        if google_sync:
            data['google_sync'] = google_sync
        headers = self.get_success_headers(data)
        return Response(data, status=status.HTTP_201_CREATED, headers=headers)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        allievo = serializer.save()
        google_sync = None
        try:
            from .google_contacts_service import sync_allievo_to_google_contacts
            google_sync = sync_allievo_to_google_contacts(allievo)
        except Exception as e:
            google_sync = {'success': False, 'error': str(e)}

        data = serializer.data
        if google_sync:
            data['google_sync'] = google_sync
        return Response(data)

    def perform_destroy(self, instance):
        # Il signal pre_delete (allievo_pre_delete_cleanup) gestisce automaticamente
        # la rimozione dai gruppi WhatsApp, l'eliminazione della chat e la rimozione da Google Contacts
        instance.delete()

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        self.perform_destroy(instance)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'], url_path='sync-google-contacts')
    def sync_google_contacts(self, request, pk=None):
        """Sincronizza manualmente il singolo allievo/prospect in Google Contacts."""
        allievo = self.get_object()
        from .google_contacts_service import sync_allievo_to_google_contacts
        res = sync_allievo_to_google_contacts(allievo)
        return Response(res)

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
        google_sync = None
        try:
            from .google_contacts_service import sync_allievo_to_google_contacts
            google_sync = sync_allievo_to_google_contacts(allievo)
        except Exception as e:
            google_sync = {'success': False, 'error': str(e)}
        data = self.get_serializer(allievo).data
        if google_sync:
            data['google_sync'] = google_sync
        return Response(data)

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

    @action(detail=True, methods=['get'], url_path='modulo-tesseramento-pdf')
    def modulo_tesseramento_pdf(self, request, pk=None):
        """
        Ritorna il file PDF del modulo di tesseramento per l'allievo specificato.
        """
        import io
        allievo = self.get_object()
        pdf_bytes = genera_pdf_modulo_tesseramento(allievo=allievo)
        if not pdf_bytes:
            raise Http404("Impossibile generare il modulo di tesseramento.")

        safe_name = "".join(c for c in f"{allievo.cognome}_{allievo.nome}" if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
        filename = f"Modulo_Tesseramento_{safe_name}.pdf"
        return FileResponse(io.BytesIO(pdf_bytes), content_type='application/pdf', filename=filename)

    @action(detail=True, methods=['post'], url_path='send-modulo-tesseramento')
    def send_modulo_tesseramento(self, request, pk=None):
        """
        Invia il modulo di tesseramento via WhatsApp all'allievo specificato.
        Input:
          - telefono: str (opzionale, default: allievo.telefono)
          - messaggio: str (opzionale)
        """
        allievo = self.get_object()
        telefono = request.data.get('telefono') or allievo.telefono
        if not telefono:
            return Response(
                {'success': False, 'error': f"L'allievo {allievo.nome} {allievo.cognome} non ha un numero di telefono associato."},
                status=status.HTTP_400_BAD_REQUEST
            )

        messaggio = request.data.get('messaggio')
        if not messaggio:
            messaggio = (
                f"Gentile {allievo.nome} {allievo.cognome}, ti inviamo in allegato il modulo per la richiesta o il rinnovo "
                f"del tesseramento all'ASD TantoTango da compilare e firmare. A presto!"
            )

        try:
            pdf_bytes = genera_pdf_modulo_tesseramento(allievo=allievo)
            if not pdf_bytes:
                return Response({'success': False, 'error': 'Impossibile generare il PDF del modulo.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            from .wa_client import send_whatsapp_document
            safe_name = "".join(c for c in f"{allievo.cognome}_{allievo.nome}" if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
            filename = f"Modulo_Tesseramento_{safe_name}.pdf"

            res = send_whatsapp_document(
                to=telefono,
                file_bytes=pdf_bytes,
                filename=filename,
                caption=messaggio
            )

            if res.get('success'):
                return Response({
                    'success': True,
                    'message': f"Modulo di tesseramento inviato con successo via WhatsApp a {telefono}!"
                })
            else:
                return Response({
                    'success': False,
                    'error': res.get('error', 'Errore gateway WhatsApp')
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        except Exception as e:
            return Response({'success': False, 'error': f"Errore invio WhatsApp: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)





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
    queryset = Pagamento.objects.select_related('allievo', 'corso', 'corso__scuola').prefetch_related('ricevute').all()
    serializer_class = PagamentoSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['allievo', 'corso', 'corso__scuola', 'trimestre']
    search_fields = ['allievo__nome', 'allievo__cognome', 'corso__scuola__nome', 'causale', 'note']
    ordering_fields = ['data_pagamento', 'importo']

    def get_queryset(self):
        qs = super().get_queryset()
        data_da = self.request.query_params.get('data_da') or self.request.query_params.get('data_inizio') or self.request.query_params.get('date_from')
        data_a = self.request.query_params.get('data_a') or self.request.query_params.get('data_fine') or self.request.query_params.get('date_to')
        data_esatta = self.request.query_params.get('data') or self.request.query_params.get('data_pagamento')
        if data_esatta:
            qs = qs.filter(data_pagamento=data_esatta)
        else:
            if data_da:
                qs = qs.filter(data_pagamento__gte=data_da)
            if data_a:
                qs = qs.filter(data_pagamento__lte=data_a)

        has_ricevuta = self.request.query_params.get('has_ricevuta')
        if has_ricevuta is not None:
            if str(has_ricevuta).lower() in ['true', '1']:
                qs = qs.filter(ricevute__isnull=False).distinct()
            elif str(has_ricevuta).lower() in ['false', '0']:
                qs = qs.filter(ricevute__isnull=True)
        return qs

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
            if 'jolly_testo' in data:
                config.jolly_testo = data['jolly_testo']

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
            ('modulo_tesseramento', 'Modulo di Tesseramento', 'Modulo PDF ufficiale per la richiesta o rinnovo del tesseramento degli allievi.'),
            ('verbale_rendiconto', 'Verbale Approvazione Rendiconto', 'Modello di verbale assembleare per l\'approvazione del rendiconto economico-finanziario annuale.')
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
            fn = template.filename.lower()
            if fn.endswith('.docx'):
                ct = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            elif fn.endswith('.doc'):
                ct = 'application/msword'
            else:
                ct = 'application/pdf'
            return FileResponse(template.file.open('rb'), content_type=ct, filename=template.filename)
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
        data_da = self.request.query_params.get('data_da') or self.request.query_params.get('data_inizio') or self.request.query_params.get('date_from')
        data_a = self.request.query_params.get('data_a') or self.request.query_params.get('data_fine') or self.request.query_params.get('date_to')
        data_esatta = self.request.query_params.get('data') or self.request.query_params.get('data_ricevuta')
        if data_esatta:
            qs = qs.filter(data=data_esatta)
        else:
            if data_da:
                qs = qs.filter(data__gte=data_da)
            if data_a:
                qs = qs.filter(data__lte=data_a)

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

    @action(detail=True, methods=['post'], url_path='upload-to-drive')
    def upload_to_drive(self, request, pk=None):
        """Salva la ricevuta PDF su Google Drive nella cartella configurata per le Ricevute."""
        ricevuta = self.get_object()
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Google Drive non configurato. Vai in Impostazioni > Google Drive per caricare la chiave privata.'
            }, status=status.HTTP_400_BAD_REQUEST)

        target_folder_id = config.folder_ricevute_id or config.folder_id
        if not target_folder_id:
            return Response({
                'success': False,
                'error': 'Nessuna cartella di destinazione impostata per le Ricevute. Selezionala in Impostazioni > Google Drive.'
            }, status=status.HTTP_400_BAD_REQUEST)

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
                return Response({'success': False, 'error': 'Impossibile generare il PDF dal template.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            from googleapiclient.http import MediaIoBaseUpload
            import io

            drive_service = get_google_drive_service(config)

            safe_name = "".join(c for c in ricevuta.intestatario if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
            filename = f"Ricevuta_{ricevuta.numero:02d}_{ricevuta.anno}_{safe_name}.pdf"

            file_metadata = {
                'name': filename,
                'parents': [target_folder_id],
                'description': f"Ricevuta {ricevuta.numero_display} per {ricevuta.intestatario} (€ {ricevuta.importo:.2f})"
            }

            media = MediaIoBaseUpload(io.BytesIO(pdf_bytes), mimetype='application/pdf', resumable=True)
            uploaded_file = drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, name, webViewLink',
                supportsAllDrives=True
            ).execute()

            return Response({
                'success': True,
                'file_id': uploaded_file.get('id'),
                'filename': uploaded_file.get('name'),
                'webViewLink': uploaded_file.get('webViewLink'),
                'folder_nome': config.folder_ricevute_nome or target_folder_id
            })
        except Exception as e:
            return Response({'success': False, 'error': f"Errore caricamento su Google Drive: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'], url_path='send-whatsapp')
    def send_whatsapp(self, request, pk=None):
        """Invia il PDF della ricevuta via WhatsApp all'intestatario."""
        ricevuta = self.get_object()
        telefono = (request.data.get('telefono') or '').strip()
        if not telefono and ricevuta.allievo and ricevuta.allievo.telefono:
            telefono = ricevuta.allievo.telefono.strip()

        if not telefono:
            return Response({
                'success': False,
                'error': "Numero di telefono mancante. Specifica il numero WhatsApp dell'intestatario."
            }, status=status.HTTP_400_BAD_REQUEST)

        messaggio = request.data.get('messaggio')
        if not messaggio:
            messaggio = f"Gentile {ricevuta.intestatario}, ti inviamo in allegato la ricevuta {ricevuta.numero_display} di € {ricevuta.importo:.2f} per '{ricevuta.causale}'."

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
                return Response({'success': False, 'error': 'Impossibile generare il PDF dal template.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            from .wa_client import send_whatsapp_document
            safe_name = "".join(c for c in ricevuta.intestatario if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
            filename = f"Ricevuta_{ricevuta.numero:02d}_{ricevuta.anno}_{safe_name}.pdf"

            res = send_whatsapp_document(
                to=telefono,
                file_bytes=pdf_bytes,
                filename=filename,
                caption=messaggio
            )

            if res.get('success'):
                return Response({
                    'success': True,
                    'message': f"Ricevuta inviata con successo via WhatsApp a {telefono}!"
                })
            else:
                return Response({
                    'success': False,
                    'error': res.get('error', 'Errore gateway WhatsApp')
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        except Exception as e:
            return Response({'success': False, 'error': f"Errore invio WhatsApp: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'], url_path='inserisci-in-cassa')
    def inserisci_in_cassa(self, request, pk=None):
        """
        Crea un movimento di entrata in Prima Nota Cassa (Bilancio) per questa ricevuta,
        oppure restituisce errore se è già presente a bilancio.
        """
        ricevuta = self.get_object()
        if ricevuta.in_bilancio:
            return Response({
                'error': f'La ricevuta {ricevuta.numero_display} è già stata aggiunta alla Prima Nota Cassa (Bilancio).'
            }, status=status.HTTP_400_BAD_REQUEST)

        categoria = request.data.get('categoria')
        if not categoria:
            causale_lower = (ricevuta.causale or '').lower()
            if 'tesser' in causale_lower or 'associat' in causale_lower or 'iscrizion' in causale_lower:
                categoria = 'Tesseramenti'
            elif 'stage' in causale_lower or 'workshop' in causale_lower:
                categoria = 'Stage / Workshop'
            elif 'privat' in causale_lower:
                categoria = 'Lezioni private'
            elif 'milong' in causale_lower or 'serat' in causale_lower:
                categoria = 'Milonghe / Serate'
            elif 'donazion' in causale_lower or 'contribut' in causale_lower:
                categoria = 'Donazioni / Contributi'
            else:
                categoria = 'Quote corsi'

        descrizione = request.data.get('descrizione')
        if not descrizione:
            descrizione = f"Ricevuta {ricevuta.numero_display} - {ricevuta.intestatario}"

        data_mov = request.data.get('data') or ricevuta.data
        note_mov = request.data.get('note')
        if note_mov is None:
            note_mov = f"Generato automaticamente da Ricevuta {ricevuta.numero_display} ({ricevuta.causale})"
            if ricevuta.note:
                note_mov += f". {ricevuta.note}"

        movimento = MovimentoPrimaNota.objects.create(
            data=data_mov,
            descrizione=descrizione,
            categoria=categoria,
            tipo='entrata',
            importo=ricevuta.importo,
            note=note_mov.strip()
        )

        ricevuta.movimento_cassa = movimento
        ricevuta.save()

        return Response({
            'success': True,
            'message': f"Entrata per Ricevuta {ricevuta.numero_display} inserita con successo in Prima Nota Cassa!",
            'ricevuta': RicevutaSerializer(ricevuta).data,
            'movimento_id': str(movimento.id),
        }, status=status.HTTP_201_CREATED)


def get_google_drive_service(config=None):
    """
    Inizializza e restituisce il servizio Google Drive v3 autorizzato,
    utilizzando le credenziali OAuth 2.0 (account personale) o Service Account
    in base alla configurazione attiva.
    """
    if not config:
        config = GoogleDriveConfig.get_instance()
    if not config.is_configured:
        raise ValueError('Google Drive non è configurato. Completa l\'accesso in Impostazioni > Google Drive.')

    from googleapiclient.discovery import build

    if config.auth_type == 'oauth':
        if not config.oauth_refresh_token:
            raise ValueError('Nessun token di autorizzazione Google OAuth 2.0 trovato. Connettiti con il tuo account Google.')
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request

        creds = Credentials(
            token=config.oauth_access_token or None,
            refresh_token=config.oauth_refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=config.oauth_client_id,
            client_secret=config.oauth_client_secret,
            scopes=[
                'https://www.googleapis.com/auth/drive',
                'https://www.googleapis.com/auth/userinfo.email',
                'https://www.googleapis.com/auth/userinfo.profile',
                'openid'
            ]
        )
        if not creds.valid:
            if creds.refresh_token:
                try:
                    creds.refresh(Request())
                    config.oauth_access_token = creds.token
                    if creds.expiry:
                        config.oauth_token_expiry = creds.expiry
                    config.save(update_fields=['oauth_access_token', 'oauth_token_expiry'])
                except Exception as e:
                    err_str = str(e)
                    if 'invalid_grant' in err_str or 'expired or revoked' in err_str:
                        raise ValueError("Il token Google OAuth è scaduto o è stato revocato. Clicca su 'Ricollega Account Google' per rinnovare l'accesso.")
                    raise ValueError(f"Impossibile aggiornare il token di accesso Google: {err_str}")
        return build('drive', 'v3', credentials=creds)

    else:
        # Service Account
        if not config.is_sa_configured:
            raise ValueError('Nessun file di credenziali Service Account configurato per Google Drive.')
        from google.oauth2 import service_account
        credentials = service_account.Credentials.from_service_account_file(
            config.credentials_file.path,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        return build('drive', 'v3', credentials=credentials)


class GoogleDriveConfigViewSet(viewsets.ViewSet):
    """
    Gestione della configurazione Google Drive (OAuth 2.0 e Service Account).
    """
    def list(self, request):
        config = GoogleDriveConfig.get_instance()
        serializer = GoogleDriveConfigSerializer(config)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='switch-auth-type')
    def switch_auth_type(self, request):
        """Passa tra OAuth 2.0 e Service Account."""
        config = GoogleDriveConfig.get_instance()
        auth_type = request.data.get('auth_type')
        if auth_type in ['oauth', 'service_account']:
            config.auth_type = auth_type
            config.save(update_fields=['auth_type'])
        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['post'], url_path='oauth-save-credentials')
    def oauth_save_credentials(self, request):
        """
        Salva Client ID e Client Secret OAuth 2.0 da form o da file client_secret.json.
        """
        config = GoogleDriveConfig.get_instance()
        file_obj = request.FILES.get('file')

        client_id = (request.data.get('client_id') or '').strip()
        client_secret = (request.data.get('client_secret') or '').strip()

        if file_obj:
            try:
                import json
                raw = file_obj.read().decode('utf-8')
                data = json.loads(raw)
                # Formato standard Google Cloud Console OAuth 2.0: {"web": {...}} o {"installed": {...}}
                root = data.get('web') or data.get('installed') or data
                client_id = root.get('client_id', '') or client_id
                client_secret = root.get('client_secret', '') or client_secret
            except Exception as e:
                return Response({'success': False, 'error': f"Errore lettura file JSON credenziali: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        if not client_id or not client_secret:
            return Response({'success': False, 'error': 'Client ID e Client Secret sono entrambi obbligatori.'}, status=status.HTTP_400_BAD_REQUEST)

        config.auth_type = 'oauth'
        config.oauth_client_id = client_id
        config.oauth_client_secret = client_secret
        config.save()

        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['get', 'post'], url_path='oauth-init')
    def oauth_init(self, request):
        """
        Genera l'URL di autorizzazione Google OAuth 2.0.
        """
        config = GoogleDriveConfig.get_instance()
        client_id = (request.data.get('client_id') or config.oauth_client_id or '').strip()
        client_secret = (request.data.get('client_secret') or config.oauth_client_secret or '').strip()

        if not client_id or not client_secret:
            return Response({
                'success': False,
                'error': 'OAuth Client ID e Client Secret non configurati. Inseriscili prima di iniziare l\'autenticazione.'
            }, status=status.HTTP_400_BAD_REQUEST)

        if client_id != config.oauth_client_id or client_secret != config.oauth_client_secret:
            config.oauth_client_id = client_id
            config.oauth_client_secret = client_secret
            config.auth_type = 'oauth'
            config.save()

        # Determina redirect_uri
        redirect_uri = request.data.get('redirect_uri')
        if not redirect_uri:
            # Costruisci redirect_uri assoluto
            redirect_uri = request.build_absolute_uri('/api/google-drive/oauth-callback/')

        import urllib.parse
        scopes = [
            'https://www.googleapis.com/auth/drive',
            'https://www.googleapis.com/auth/userinfo.email',
            'https://www.googleapis.com/auth/userinfo.profile',
            'openid'
        ]
        params = {
            'client_id': config.oauth_client_id,
            'redirect_uri': redirect_uri,
            'response_type': 'code',
            'scope': ' '.join(scopes),
            'access_type': 'offline',
            'prompt': 'consent',
            'include_granted_scopes': 'true',
            'state': redirect_uri,
        }
        auth_url = 'https://accounts.google.com/o/oauth2/v2/auth?' + urllib.parse.urlencode(params)
        return Response({
            'success': True,
            'auth_url': auth_url,
            'redirect_uri': redirect_uri
        })

    @action(detail=False, methods=['get'], url_path='oauth-callback', permission_classes=[permissions.AllowAny])
    def oauth_callback(self, request):
        """
        Riceve il redirect da Google con il codice di autorizzazione OAuth 2.0.
        """
        error = request.query_params.get('error')
        if error:
            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore Google OAuth</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Errore durante l'autenticazione con Google</h2>
                <p>Messaggio: {error}</p>
                <p>Puoi chiudere questa finestra e riprovare.</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        code = request.query_params.get('code')
        if not code:
            return HttpResponse("""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Nessun codice di autorizzazione fornito</h2>
                <p>Puoi chiudere questa finestra.</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        config = GoogleDriveConfig.get_instance()
        if not config.oauth_client_id or not config.oauth_client_secret:
            return HttpResponse("""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Credenziali mancanti</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Client ID o Client Secret mancanti</h2>
                <p>Configura prima le credenziali OAuth in WAManager.</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        state = request.query_params.get('state')
        if state and state.startswith('http'):
            redirect_uri = state
        else:
            redirect_uri = request.build_absolute_uri(request.path)

        try:
            import requests
            import datetime

            token_resp = requests.post('https://oauth2.googleapis.com/token', data={
                'code': code,
                'client_id': config.oauth_client_id,
                'client_secret': config.oauth_client_secret,
                'redirect_uri': redirect_uri,
                'grant_type': 'authorization_code'
            })

            if token_resp.status_code != 200:
                return HttpResponse(f"""
                <!DOCTYPE html>
                <html>
                <head><meta charset="utf-8"><title>Errore Scambio Token</title></head>
                <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                    <h2 style="color: #d32f2f;">Impossibile completare lo scambio del token</h2>
                    <pre style="background: #f5f5f5; padding: 15px; display: inline-block; text-align: left; border-radius: 8px;">{token_resp.text}</pre>
                </body>
                </html>
                """, content_type="text/html; charset=utf-8")

            tokens = token_resp.json()
            access_token = tokens.get('access_token')
            refresh_token = tokens.get('refresh_token')
            expires_in = tokens.get('expires_in', 3600)

            user_email = ''
            user_name = ''
            user_resp = requests.get('https://www.googleapis.com/oauth2/v3/userinfo', headers={
                'Authorization': f'Bearer {access_token}'
            })
            if user_resp.status_code == 200:
                u_info = user_resp.json()
                user_email = u_info.get('email', '')
                user_name = u_info.get('name', '')

            config.auth_type = 'oauth'
            config.oauth_access_token = access_token
            if refresh_token:
                config.oauth_refresh_token = refresh_token
            config.oauth_token_expiry = timezone.now() + datetime.timedelta(seconds=expires_in)
            config.oauth_user_email = user_email
            config.oauth_user_name = user_name
            config.last_test_status = 'success'
            config.last_test_message = f"Connesso via OAuth 2.0 come {user_email or user_name}"
            config.last_tested_at = timezone.now()
            config.save()

            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Google Drive Connesso!</title>
                <style>
                    body {{
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        background-color: #f0f4f9;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        margin: 0;
                    }}
                    .card {{
                        background: white;
                        padding: 40px 32px;
                        border-radius: 20px;
                        box-shadow: 0 10px 30px rgba(0,0,0,0.08);
                        text-align: center;
                        max-width: 440px;
                        width: 90%;
                    }}
                    .icon {{ font-size: 56px; margin-bottom: 12px; }}
                    h2 {{ color: #1a73e8; margin-bottom: 8px; font-size: 22px; }}
                    p {{ color: #5f6368; font-size: 14px; line-height: 1.5; }}
                    .email-badge {{
                        background: #e8f0fe;
                        color: #1967d2;
                        font-weight: 600;
                        padding: 8px 16px;
                        border-radius: 20px;
                        display: inline-block;
                        margin: 14px 0;
                        font-size: 15px;
                    }}
                    .close-notice {{ font-size: 12px; color: #9aa0a6; margin-top: 16px; }}
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="icon">✅</div>
                    <h2>Account Google Connesso!</h2>
                    <p>L'integrazione Google Drive è attiva per:</p>
                    <div class="email-badge">{user_email or user_name}</div>
                    <p>Tutti i caricamenti di ricevute e tessere utilizzeranno ora la tua quota personale di 15 GB.</p>
                    <p class="close-notice">Questa finestra si chiuderà automaticamente...</p>
                </div>
                <script>
                    if (window.opener) {{
                        try {{
                            window.opener.postMessage({{
                                type: 'GOOGLE_DRIVE_OAUTH_SUCCESS',
                                email: '{user_email}',
                                name: '{user_name}'
                            }}, '*');
                        }} catch (e) {{}}
                        setTimeout(function() {{
                            window.close();
                        }}, 2000);
                    }}
                </script>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        except Exception as e:
            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Errore imprevisto durante l'autenticazione</h2>
                <p>{str(e)}</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

    @action(detail=False, methods=['post'], url_path='oauth-disconnect')
    def oauth_disconnect(self, request):
        """
        Disconnette l'account Google OAuth 2.0 revocando/azzerando i token salvati.
        """
        config = GoogleDriveConfig.get_instance()
        config.oauth_access_token = ''
        config.oauth_refresh_token = ''
        config.oauth_token_expiry = None
        config.oauth_user_email = ''
        config.oauth_user_name = ''
        config.last_test_status = ''
        config.last_test_message = ''
        config.last_tested_at = None
        config.save()

        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['post'], url_path='upload')
    def upload_file(self, request):
        """
        Carica un file di credenziali JSON. Rileva automaticamente se si tratta di
        chiave privata Service Account o file client_secret OAuth 2.0.
        """
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'success': False, 'error': 'Nessun file fornito.'}, status=status.HTTP_400_BAD_REQUEST)

        config = GoogleDriveConfig.get_instance()
        content_bytes = file_obj.read()
        file_obj.seek(0)

        import json
        is_service_account = False
        is_oauth_client = False
        client_id = ''
        client_secret = ''
        client_email = ''
        project_id = ''
        private_key_id = ''

        try:
            data = json.loads(content_bytes.decode('utf-8'))
            if isinstance(data, dict):
                if data.get('type') == 'service_account':
                    is_service_account = True
                    client_email = data.get('client_email', '')
                    project_id = data.get('project_id', '')
                    private_key_id = data.get('private_key_id', '')
                elif 'web' in data or 'installed' in data:
                    is_oauth_client = True
                    root = data.get('web') or data.get('installed')
                    client_id = root.get('client_id', '')
                    client_secret = root.get('client_secret', '')
                elif 'client_id' in data and 'client_secret' in data:
                    is_oauth_client = True
                    client_id = data.get('client_id', '')
                    client_secret = data.get('client_secret', '')
        except Exception as e:
            return Response({'success': False, 'error': f"File JSON non valido: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        if is_oauth_client:
            config.auth_type = 'oauth'
            config.oauth_client_id = client_id
            config.oauth_client_secret = client_secret
            config.save()
            serializer = GoogleDriveConfigSerializer(config)
            return Response({
                'success': True,
                'detected_type': 'oauth',
                'message': 'File credenziali OAuth 2.0 caricato con successo! Clicca su "Connetti con Google" per autorizzare il tuo account.',
                'config': serializer.data
            })

        # Altrimenti gestisce come Service Account
        if config.credentials_file:
            try:
                config.credentials_file.delete(save=False)
            except Exception:
                pass

        config.credentials_file = file_obj
        config.client_email = client_email
        config.project_id = project_id
        config.private_key_id = private_key_id
        config.auth_type = 'service_account'
        config.last_test_status = ''
        config.last_test_message = ''
        config.last_tested_at = None
        config.save()

        serializer = GoogleDriveConfigSerializer(config)
        return Response({
            'success': True,
            'detected_type': 'service_account',
            'config': serializer.data
        })

    @action(detail=False, methods=['post'], url_path='test')
    def test_connection(self, request):
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Google Drive non è configurato. Completa l\'accesso prima di testare.'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            drive_service = get_google_drive_service(config)

            about = drive_service.about().get(fields='user, storageQuota').execute()
            user_info = about.get('user', {})
            user_display = user_info.get('displayName') or user_info.get('emailAddress') or config.oauth_user_email or config.client_email or 'Google Drive'

            quota_info = about.get('storageQuota', {})
            limit = quota_info.get('limit')
            usage = quota_info.get('usage')
            quota_str = ""
            if limit and usage:
                limit_gb = int(limit) / (1024**3)
                usage_gb = int(usage) / (1024**3)
                quota_str = f" • Quota: {usage_gb:.2f} GB usati di {limit_gb:.1f} GB ({int((int(usage)/int(limit))*100)}%)"

            config.last_test_status = 'success'
            config.last_test_message = f"Connessione riuscita! Account: {user_display}{quota_str}"
            config.last_tested_at = timezone.now()
            config.save()

            serializer = GoogleDriveConfigSerializer(config)
            return Response({'success': True, 'config': serializer.data, 'message': config.last_test_message})
        except Exception as e:
            err_str = str(e)
            config.last_test_status = 'error'
            if 'invalid_grant' in err_str or 'expired or revoked' in err_str:
                config.last_test_message = "Token Google scaduto o revocato. Clicca sul pulsante 'Ricollega Account Google' per riattivare la sessione."
            else:
                config.last_test_message = f"Errore connessione Google Drive: {err_str}"
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

    @action(detail=False, methods=['get'], url_path='folders')
    def list_folders(self, request):
        """
        Sfoglia l'alberatura delle cartelle di Google Drive.
        Supporta sia OAuth 2.0 (Drive personale e Condivisi con me) sia Service Account.
        """
        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Google Drive non configurato. Completa prima l\'accesso in Impostazioni.'
            }, status=status.HTTP_400_BAD_REQUEST)

        parent_id = (request.query_params.get('parent_id') or '').strip()

        try:
            drive_service = get_google_drive_service(config)

            if not parent_id or parent_id == 'root':
                items_dict = {}

                # 1. Cartelle radice di "Il mio Drive"
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

                # 2. Cartelle condivise (sharedWithMe)
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
                            'name': f.get('name', 'Senza nome') + (' (Condivisa)' if f['id'] not in items_dict else ''),
                            'is_shared': True,
                            'parents': f.get('parents', []),
                        }
                except Exception as e:
                    print(f"Avviso cartelle sharedWithMe: {e}")

                # 3. Shared Drives (Team Drives)
                try:
                    res_drives = drive_service.drives().list(pageSize=50).execute()
                    for d in res_drives.get('drives', []):
                        items_dict[d['id']] = {
                            'id': d['id'],
                            'name': d.get('name', 'Shared Drive') + ' (Unità Condivisa)',
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
                        'name': 'Il mio Drive / Condivisi',
                        'parents': [],
                    },
                    'breadcrumbs': [
                        {'id': 'root', 'name': 'Drive (Radice)'}
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
            drive_service = get_google_drive_service(config)
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
            'folder_tessere_nome',
            'folder_verbali_id',
            'folder_verbali_nome'
        ]
        for f in folder_fields:
            if f in request.data:
                setattr(config, f, str(request.data.get(f) or '').strip())

        if 'is_active' in request.data:
            config.is_active = bool(request.data.get('is_active'))

        config.save()
        serializer = GoogleDriveConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})


# ─── 2.14b Google Contacts Configuration (OAuth 2.0) ─────────────

class GoogleContactsConfigViewSet(viewsets.ViewSet):
    """
    Gestione della configurazione Google Contacts (OAuth 2.0).
    Consente di inserire Client ID e Client Secret e collegare l'account Google.
    """
    def list(self, request):
        config = GoogleContactsConfig.get_instance()
        serializer = GoogleContactsConfigSerializer(config)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='save-credentials')
    def save_credentials(self, request):
        """
        Salva Client ID e Client Secret OAuth 2.0 (da form o da file JSON caricato).
        """
        config = GoogleContactsConfig.get_instance()
        file_obj = request.FILES.get('file')

        client_id = (request.data.get('client_id') or '').strip()
        client_secret = (request.data.get('client_secret') or '').strip()

        if file_obj:
            try:
                import json
                raw = file_obj.read().decode('utf-8')
                data = json.loads(raw)
                root = data.get('web') or data.get('installed') or data
                client_id = root.get('client_id', '') or client_id
                client_secret = root.get('client_secret', '') or client_secret
            except Exception as e:
                return Response({'success': False, 'error': f"Errore lettura file JSON credenziali: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        if not client_id or not client_secret:
            return Response({'success': False, 'error': 'Client ID e Client Secret sono entrambi obbligatori.'}, status=status.HTTP_400_BAD_REQUEST)

        config.client_id = client_id
        config.client_secret = client_secret
        config.save()

        serializer = GoogleContactsConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['get', 'post'], url_path='oauth-init')
    def oauth_init(self, request):
        """
        Genera l'URL di autorizzazione Google OAuth 2.0 per Google Contacts (People API).
        """
        config = GoogleContactsConfig.get_instance()
        client_id = (request.data.get('client_id') or config.client_id or '').strip()
        client_secret = (request.data.get('client_secret') or config.client_secret or '').strip()

        if not client_id or not client_secret:
            return Response({
                'success': False,
                'error': 'OAuth Client ID e Client Secret non configurati. Inseriscili prima di iniziare l\'autenticazione.'
            }, status=status.HTTP_400_BAD_REQUEST)

        if client_id != config.client_id or client_secret != config.client_secret:
            config.client_id = client_id
            config.client_secret = client_secret
            config.save()

        redirect_uri = request.data.get('redirect_uri')
        if not redirect_uri:
            redirect_uri = request.build_absolute_uri('/api/google-contacts/oauth-callback/')

        import urllib.parse
        scopes = [
            'https://www.googleapis.com/auth/contacts',
            'https://www.googleapis.com/auth/userinfo.email',
            'https://www.googleapis.com/auth/userinfo.profile',
            'openid'
        ]
        params = {
            'client_id': config.client_id,
            'redirect_uri': redirect_uri,
            'response_type': 'code',
            'scope': ' '.join(scopes),
            'access_type': 'offline',
            'prompt': 'consent',
            'include_granted_scopes': 'true',
            'state': redirect_uri,
        }
        auth_url = 'https://accounts.google.com/o/oauth2/v2/auth?' + urllib.parse.urlencode(params)
        return Response({
            'success': True,
            'auth_url': auth_url,
            'redirect_uri': redirect_uri
        })

    @action(detail=False, methods=['get'], url_path='oauth-callback', permission_classes=[permissions.AllowAny])
    def oauth_callback(self, request):
        """
        Riceve il redirect da Google con il codice di autorizzazione OAuth 2.0.
        """
        error = request.query_params.get('error')
        if error:
            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore Google Contacts OAuth</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Errore durante l'autenticazione con Google Contacts</h2>
                <p>Messaggio: {error}</p>
                <p>Puoi chiudere questa finestra e riprovare.</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        code = request.query_params.get('code')
        if not code:
            return HttpResponse("""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Nessun codice di autorizzazione ricevuto</h2>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        config = GoogleContactsConfig.get_instance()
        redirect_uri = request.query_params.get('state') or request.build_absolute_uri('/api/google-contacts/oauth-callback/')

        import requests
        try:
            token_url = 'https://oauth2.googleapis.com/token'
            payload = {
                'code': code,
                'client_id': config.client_id,
                'client_secret': config.client_secret,
                'redirect_uri': redirect_uri,
                'grant_type': 'authorization_code',
            }
            resp = requests.post(token_url, data=payload, timeout=15)
            if resp.status_code != 200:
                err_data = resp.json() if resp.headers.get('content-type', '').startswith('application/json') else {}
                err_msg = err_data.get('error_description') or err_data.get('error') or resp.text
                return HttpResponse(f"""
                <!DOCTYPE html>
                <html>
                <head><meta charset="utf-8"><title>Errore Scambio Token</title></head>
                <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                    <h2 style="color: #d32f2f;">Errore scambio token con Google</h2>
                    <p style="color: #555;">{err_msg}</p>
                    <p><a href="javascript:window.close()">Chiudi finestra</a></p>
                </body>
                </html>
                """, content_type="text/html; charset=utf-8")

            token_data = resp.json()
            access_token = token_data.get('access_token')
            refresh_token = token_data.get('refresh_token')
            expires_in = token_data.get('expires_in', 3600)

            user_email = ''
            user_name = ''
            try:
                user_info_resp = requests.get(
                    'https://www.googleapis.com/oauth2/v2/userinfo',
                    headers={'Authorization': f'Bearer {access_token}'},
                    timeout=10
                )
                if user_info_resp.status_code == 200:
                    u_data = user_info_resp.json()
                    user_email = u_data.get('email', '')
                    user_name = u_data.get('name', '')
            except Exception:
                pass

            config.access_token = access_token
            if refresh_token:
                config.refresh_token = refresh_token
            config.token_expiry = timezone.now() + datetime.timedelta(seconds=expires_in)
            config.user_email = user_email
            config.user_name = user_name
            config.last_test_status = 'success'
            config.last_test_message = 'Autenticazione OAuth 2.0 completata con successo.'
            config.save()

            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Google Contacts Collegato</title>
                <style>
                    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; text-align: center; padding: 40px; background: #f8fafc; color: #1e293b; }}
                    .card {{ max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.08); }}
                    .icon {{ width: 64px; height: 64px; background: #ecfdf5; color: #059669; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 32px; margin: 0 auto 16px; }}
                    h2 {{ margin: 0 0 8px; color: #065f46; }}
                    p {{ color: #475569; font-size: 14px; margin-bottom: 24px; }}
                    .email {{ font-weight: bold; color: #1e293b; background: #f1f5f9; padding: 8px 16px; border-radius: 8px; display: inline-block; margin-bottom: 24px; }}
                    button {{ background: #059669; color: white; border: none; padding: 12px 24px; border-radius: 8px; font-weight: 600; cursor: pointer; font-size: 14px; }}
                    button:hover {{ background: #047857; }}
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="icon">✓</div>
                    <h2>Google Contacts Collegato!</h2>
                    <p>L'account Google è stato collegato con successo al gestionale.</p>
                    <div class="email">{user_email or 'Account Google'}</div>
                    <div>
                        <button onclick="window.close()">Chiudi questa finestra</button>
                    </div>
                </div>
                <script>
                    setTimeout(function() {{
                        try {{ window.close(); }} catch(e) {{}}
                    }}, 2500);
                </script>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

        except Exception as e:
            return HttpResponse(f"""
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Errore</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h2 style="color: #d32f2f;">Errore imprevisto durante l'autenticazione</h2>
                <p>{str(e)}</p>
            </body>
            </html>
            """, content_type="text/html; charset=utf-8")

    @action(detail=False, methods=['post'], url_path='oauth-disconnect')
    def oauth_disconnect(self, request):
        """
        Disconnette l'account Google Contacts revocando/azzerando i token salvati.
        """
        config = GoogleContactsConfig.get_instance()
        config.access_token = ''
        config.refresh_token = ''
        config.token_expiry = None
        config.user_email = ''
        config.user_name = ''
        config.last_test_status = ''
        config.last_test_message = ''
        config.last_sync_at = None
        config.save()

        serializer = GoogleContactsConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['post'], url_path='test-connection')
    def test_connection(self, request):
        """
        Verifica la validità del token e l'accesso alla People API di Google.
        """
        config = GoogleContactsConfig.get_instance()
        if not config.refresh_token:
            return Response({
                'success': False,
                'status': 'not_configured',
                'message': 'Nessun account Google Contacts collegato via OAuth 2.0.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Refresh token se necessario
        import requests
        access_token = config.access_token
        need_refresh = not access_token or not config.token_expiry or config.token_expiry <= timezone.now()

        if need_refresh and config.refresh_token:
            try:
                resp = requests.post(
                    'https://oauth2.googleapis.com/token',
                    data={
                        'client_id': config.client_id,
                        'client_secret': config.client_secret,
                        'refresh_token': config.refresh_token,
                        'grant_type': 'refresh_token'
                    },
                    timeout=15
                )
                if resp.status_code == 200:
                    t_data = resp.json()
                    access_token = t_data.get('access_token')
                    expires_in = t_data.get('expires_in', 3600)
                    config.access_token = access_token
                    config.token_expiry = timezone.now() + datetime.timedelta(seconds=expires_in)
                    config.save()
                else:
                    err_msg = resp.text
                    config.last_test_status = 'error'
                    config.last_test_message = f"Errore rinnovo token: {err_msg}"
                    config.save()
                    return Response({'success': False, 'status': 'error', 'message': config.last_test_message})
            except Exception as e:
                config.last_test_status = 'error'
                config.last_test_message = f"Errore connessione: {str(e)}"
                config.save()
                return Response({'success': False, 'status': 'error', 'message': config.last_test_message})

        # Test chiamata People API
        try:
            test_resp = requests.get(
                'https://people.googleapis.com/v1/people/me?personFields=names,emailAddresses',
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=15
            )
            if test_resp.status_code == 200:
                p_data = test_resp.json()
                names = p_data.get('names', [])
                display_name = names[0].get('displayName') if names else config.user_name
                config.last_test_status = 'success'
                config.last_test_message = f"Connessione a Google Contacts attiva e funzionante ({display_name or config.user_email})."
                config.save()
                return Response({
                    'success': True,
                    'status': 'success',
                    'message': config.last_test_message,
                    'config': GoogleContactsConfigSerializer(config).data
                })
            else:
                err_msg = test_resp.json().get('error', {}).get('message') or test_resp.text
                config.last_test_status = 'error'
                config.last_test_message = f"Errore People API ({test_resp.status_code}): {err_msg}"
                config.save()
                return Response({'success': False, 'status': 'error', 'message': config.last_test_message})
        except Exception as e:
            config.last_test_status = 'error'
            config.last_test_message = f"Eccezione chiamata People API: {str(e)}"
            config.save()
            return Response({'success': False, 'status': 'error', 'message': config.last_test_message})

    @action(detail=False, methods=['post'], url_path='save-settings')
    def save_settings(self, request):
        """
        Salva impostazioni aggiuntive (es. nome gruppo etichetta contatti, stato attivo).
        """
        config = GoogleContactsConfig.get_instance()
        if 'sync_group_name' in request.data:
            config.sync_group_name = str(request.data.get('sync_group_name') or '').strip()
        if 'is_active' in request.data:
            config.is_active = bool(request.data.get('is_active'))
        config.save()
        serializer = GoogleContactsConfigSerializer(config)
        return Response({'success': True, 'config': serializer.data})

    @action(detail=False, methods=['post'], url_path='sync-all-contacts')
    def sync_all_contacts(self, request):
        """
        Sincronizza in massa tutti gli allievi e prospect con Google Contacts.
        """
        from .google_contacts_service import sync_all_allievi_to_google_contacts
        result = sync_all_allievi_to_google_contacts()
        return Response(result)

    @action(detail=False, methods=['get'], url_path='comparison')
    def comparison(self, request):
        """
        Restituisce la tabella di confronto dettagliata tra Gestionale e Google Contacts:
        Allievi, Prospect e Contatti Google marcati allievo/allieva, con differenze e stato.
        """
        from .google_contacts_service import get_contacts_comparison_report
        report = get_contacts_comparison_report()
        return Response(report)

    @action(detail=False, methods=['post'], url_path='run-full-sync')
    def run_full_sync_action(self, request):
        """
        Avvia la sincronizzazione completa e bidirezionale tra il sistema e Google Contacts.
        """
        from .google_contacts_service import run_full_sync
        res = run_full_sync()
        return Response(res)

    @action(detail=False, methods=['post'], url_path='push-to-google')
    def push_to_google(self, request):
        """
        Invia/crea o aggiorna l'allievo locale su Google Contacts.
        """
        allievo_id = request.data.get('allievo_id')
        if not allievo_id:
            return Response({'success': False, 'error': 'allievo_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        allievo = Allievo.objects.filter(id=allievo_id).first()
        if not allievo:
            return Response({'success': False, 'error': 'Allievo non trovato.'}, status=status.HTTP_404_NOT_FOUND)
        from .google_contacts_service import sync_allievo_to_google_contacts
        res = sync_allievo_to_google_contacts(allievo)
        return Response(res)

    @action(detail=False, methods=['post'], url_path='pull-from-google')
    def pull_from_google(self, request):
        """
        Aggiorna l'allievo locale con i dati provenienti da Google Contacts.
        """
        allievo_id = request.data.get('allievo_id')
        google_id = request.data.get('google_id')
        if not allievo_id:
            return Response({'success': False, 'error': 'allievo_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        from .google_contacts_service import pull_google_to_system
        res = pull_google_to_system(allievo_id, google_id)
        return Response(res)

    @action(detail=False, methods=['post'], url_path='import-from-google')
    def import_from_google(self, request):
        """
        Importa un contatto da Google Contacts nel gestionale creando un Allievo o Prospect.
        """
        google_id = request.data.get('google_id')
        as_prospect = request.data.get('as_prospect')
        corso_id = request.data.get('corso_id')
        if not google_id:
            return Response({'success': False, 'error': 'google_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        from .google_contacts_service import import_google_contact_to_system
        res = import_google_contact_to_system(google_id, as_prospect=as_prospect, corso_id=corso_id)
        return Response(res)

    @action(detail=False, methods=['post'], url_path='delete-google-contact')
    def delete_google_contact_action(self, request):
        """
        Elimina il contatto specificato da Google Contacts (previa conferma utente).
        """
        google_id = request.data.get('google_id')
        allievo_id = request.data.get('allievo_id')
        if not google_id:
            return Response({'success': False, 'error': 'google_id obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        from .google_contacts_service import delete_google_contact
        res = delete_google_contact(google_id)
        if allievo_id:
            allievo = Allievo.objects.filter(id=allievo_id).first()
            if allievo:
                allievo.google_contact_id = ''
                allievo.save(update_fields=['google_contact_id'])
        return Response(res)

    @action(detail=False, methods=['get'], url_path='sync-logs')
    def sync_logs(self, request):
        """
        Restituisce la cronologia dei log di sincronizzazione Google Contacts.
        """
        from .models import GoogleContactsSyncLog
        from .serializers import GoogleContactsSyncLogSerializer
        logs = GoogleContactsSyncLog.objects.all()[:50]
        serializer = GoogleContactsSyncLogSerializer(logs, many=True)
        return Response(serializer.data)


# ─── 2.15 Bilancio: Prima Nota Cassa ────────────────────────────

class MovimentoPrimaNotaViewSet(viewsets.ModelViewSet):
    queryset = MovimentoPrimaNota.objects.all().order_by('-data', '-created_at')
    serializer_class = MovimentoPrimaNotaSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['tipo', 'categoria']
    search_fields = ['descrizione', 'categoria', 'note']
    ordering_fields = ['data', 'importo', 'categoria', 'created_at']

    def get_queryset(self):
        qs = super().get_queryset()

        anno = self.request.query_params.get('anno')
        if anno:
            try:
                qs = qs.filter(data__year=int(anno))
            except ValueError:
                pass

        mese = self.request.query_params.get('mese')
        if mese:
            try:
                qs = qs.filter(data__month=int(mese))
            except ValueError:
                pass

        data_da = self.request.query_params.get('data_da')
        if data_da:
            qs = qs.filter(data__gte=data_da)

        data_a = self.request.query_params.get('data_a')
        if data_a:
            qs = qs.filter(data__lte=data_a)

        return qs

    @action(detail=False, methods=['get'], url_path='riepilogo')
    def riepilogo(self, request):
        """Restituisce il riepilogo con totale entrate, totale uscite, saldo, categorie e anni."""
        qs = self.get_queryset()
        from django.db.models import Sum

        totale_entrate = qs.filter(tipo='entrata').aggregate(tot=Sum('importo'))['tot'] or 0.0
        totale_uscite = qs.filter(tipo='uscita').aggregate(tot=Sum('importo'))['tot'] or 0.0
        saldo = float(totale_entrate) - float(totale_uscite)

        CategoriaBilancio.ensure_defaults()

        categorie_entrate = list(CategoriaBilancio.objects.filter(tipo='entrata').order_by('ordine', 'nome').values_list('nome', flat=True))
        categorie_uscite = list(CategoriaBilancio.objects.filter(tipo='uscita').order_by('ordine', 'nome').values_list('nome', flat=True))

        categorie_db = list(MovimentoPrimaNota.objects.values_list('categoria', flat=True).distinct())
        categorie_combinate = sorted(list(set([c for c in (categorie_entrate + categorie_uscite + categorie_db) if c and c.strip()])))

        anni = list(MovimentoPrimaNota.objects.dates('data', 'year').values_list('data__year', flat=True))
        anni = sorted(list(set([y for y in anni if y >= 2026])), reverse=True)
        cur_year = max(2026, timezone.now().year)
        if cur_year not in anni:
            anni.insert(0, cur_year)

        return Response({
            'conteggio': qs.count(),
            'totale_entrate': float(totale_entrate),
            'totale_uscite': float(totale_uscite),
            'saldo': saldo,
            'categorie': categorie_combinate,
            'categorie_entrate': categorie_entrate,
            'categorie_uscite': categorie_uscite,
            'anni': anni,
        })

    @action(detail=False, methods=['get'], url_path='bilancio-mensile')
    def bilancio_mensile(self, request):
        """
        Restituisce il prospetto mensile (1-12) delle entrate, uscite, saldo e stato (avanzo, perdita, pareggio) per un anno.
        """
        from django.db.models import Sum

        anno_param = request.query_params.get('anno')
        try:
            anno = int(anno_param) if anno_param else max(2026, timezone.now().year)
        except ValueError:
            anno = max(2026, timezone.now().year)
        if anno < 2026:
            anno = 2026

        qs_anno = MovimentoPrimaNota.objects.filter(data__year=anno)

        nomi_mesi = [
            'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
            'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
        ]

        prospetto_mesi = []
        tot_entrate_anno = 0.0
        tot_uscite_anno = 0.0

        for mese_idx in range(1, 13):
            qs_mese = qs_anno.filter(data__month=mese_idx)
            entrate = float(qs_mese.filter(tipo='entrata').aggregate(tot=Sum('importo'))['tot'] or 0.0)
            uscite = float(qs_mese.filter(tipo='uscita').aggregate(tot=Sum('importo'))['tot'] or 0.0)
            saldo = entrate - uscite

            if saldo > 0.001:
                stato = 'avanzo'
                stato_display = 'Avanzo'
            elif saldo < -0.001:
                stato = 'perdita'
                stato_display = 'Perdita'
            else:
                stato = 'pareggio'
                stato_display = 'Pareggio'

            tot_entrate_anno += entrate
            tot_uscite_anno += uscite

            prospetto_mesi.append({
                'mese': mese_idx,
                'nome_mese': nomi_mesi[mese_idx - 1],
                'entrate': entrate,
                'uscite': uscite,
                'saldo': saldo,
                'stato': stato,
                'stato_display': stato_display,
                'movimenti_count': qs_mese.count(),
            })

        saldo_totale = tot_entrate_anno - tot_uscite_anno
        if saldo_totale > 0.001:
            stato_totale = 'avanzo'
            stato_totale_display = 'Avanzo'
        elif saldo_totale < -0.001:
            stato_totale = 'perdita'
            stato_totale_display = 'Perdita'
        else:
            stato_totale = 'pareggio'
            stato_totale_display = 'Pareggio'

        anni = list(MovimentoPrimaNota.objects.dates('data', 'year').values_list('data__year', flat=True))
        anni = sorted(list(set([y for y in anni if y >= 2026])), reverse=True)
        cur_year = max(2026, timezone.now().year)
        if cur_year not in anni:
            anni.insert(0, cur_year)

        return Response({
            'anno': anno,
            'anni_disponibili': anni,
            'mesi': prospetto_mesi,
            'totale_entrate': tot_entrate_anno,
            'totale_uscite': tot_uscite_anno,
            'saldo_totale': saldo_totale,
            'stato_totale': stato_totale,
            'stato_totale_display': stato_totale_display,
        })

    @action(detail=False, methods=['get'], url_path='bilancio-annuale')
    def bilancio_annuale(self, request):
        """
        Restituisce il bilancio annuale con due tabelle distinte (Entrate e Uscite),
        con colonne: VOCE (categoria), GEN, FEB, MAR, APR, MAG, GIU, LUG, AGO, SET, OTT, NOV, DIC, TOTALE.
        """
        from django.db.models import Sum

        anno_param = request.query_params.get('anno')
        try:
            anno = int(anno_param) if anno_param else max(2026, timezone.now().year)
        except ValueError:
            anno = max(2026, timezone.now().year)
        if anno < 2026:
            anno = 2026

        CategoriaBilancio.ensure_defaults()
        qs_anno = MovimentoPrimaNota.objects.filter(data__year=anno)

        def elabora_tipo(tipo_val):
            # Categorie configurate
            cat_config = list(CategoriaBilancio.objects.filter(tipo=tipo_val).order_by('ordine', 'nome').values_list('nome', flat=True))
            # Categorie presenti nei movimenti dell'anno
            cat_mov = list(qs_anno.filter(tipo=tipo_val).values_list('categoria', flat=True).distinct())

            tutte_cat = []
            for c in cat_config:
                if c not in tutte_cat:
                    tutte_cat.append(c)
            for c in sorted(cat_mov):
                if c and c not in tutte_cat:
                    tutte_cat.append(c)

            righe = []
            totali_mesi = [0.0] * 12
            totale_complessivo = 0.0

            for cat in tutte_cat:
                importi_mesi = []
                tot_riga = 0.0
                for m in range(1, 13):
                    val = float(qs_anno.filter(tipo=tipo_val, categoria=cat, data__month=m).aggregate(tot=Sum('importo'))['tot'] or 0.0)
                    importi_mesi.append(val)
                    tot_riga += val
                    totali_mesi[m - 1] += val

                totale_complessivo += tot_riga
                righe.append({
                    'categoria': cat,
                    'mesi': importi_mesi,
                    'totale': tot_riga,
                })

            return {
                'righe': righe,
                'totali_mesi': totali_mesi,
                'totale_complessivo': totale_complessivo,
            }

        dati_entrate = elabora_tipo('entrata')
        dati_uscite = elabora_tipo('uscita')

        saldo_mesi = [
            round(dati_entrate['totali_mesi'][i] - dati_uscite['totali_mesi'][i], 2)
            for i in range(12)
        ]
        saldo_complessivo = round(dati_entrate['totale_complessivo'] - dati_uscite['totale_complessivo'], 2)

        anni = list(MovimentoPrimaNota.objects.dates('data', 'year').values_list('data__year', flat=True))
        anni = sorted(list(set([y for y in anni if y >= 2026])), reverse=True)
        cur_year = max(2026, timezone.now().year)
        if cur_year not in anni:
            anni.insert(0, cur_year)

        mesi_labels = ['GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU', 'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC']

        return Response({
            'anno': anno,
            'anni_disponibili': anni,
            'mesi_labels': mesi_labels,
            'entrate': dati_entrate,
            'uscite': dati_uscite,
            'saldo_mesi': saldo_mesi,
            'saldo_complessivo': saldo_complessivo,
        })


class CategoriaBilancioViewSet(viewsets.ModelViewSet):

    """
    CRUD completo per le categorie di Bilancio (Entrate e Uscite).
    """
    queryset = CategoriaBilancio.objects.all()
    serializer_class = CategoriaBilancioSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['tipo']
    search_fields = ['nome', 'descrizione']
    ordering_fields = ['tipo', 'ordine', 'nome', 'created_at']
    ordering = ['tipo', 'ordine', 'nome']

    def get_queryset(self):
        CategoriaBilancio.ensure_defaults()
        return super().get_queryset()

    @action(detail=False, methods=['post'], url_path='reset-defaults')
    def reset_defaults(self, request):
        """Ripristina o reintegra le categorie predefinite per entrate e uscite."""
        CategoriaBilancio.ensure_defaults()
        serializer = self.get_serializer(self.get_queryset(), many=True)
        return Response({
            'success': True,
            'message': 'Categorie predefinite verificate e integrate con successo.',
            'categorie': serializer.data
        })


# ─── 2.15 Configurazione ASD & Membri Direttivo ─────────────────

class ConfigurazioneASDViewSet(viewsets.ViewSet):
    """
    Gestione e configurazione dei dati generali dell'ASD (nome, CF, sede legale, sede operativa, ecc.).
    """
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        asd = ConfigurazioneASD.get_instance()
        serializer = ConfigurazioneASDSerializer(asd)
        return Response(serializer.data)

    @action(detail=False, methods=['post', 'put', 'patch'], url_path='salva')
    def salva(self, request):
        asd = ConfigurazioneASD.get_instance()
        serializer = ConfigurazioneASDSerializer(asd, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Dati ASD aggiornati con successo.',
                'dati': serializer.data
            })
        return Response({
            'success': False,
            'error': 'Dati non validi.',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'], url_path='dati-verbale-default')
    def dati_verbale_default(self, request):
        """
        Restituisce i dati iniziali e di verifica per la generazione del verbale di approvazione rendiconto.
        """
        import datetime
        now = timezone.now()
        cur_year = now.year
        anno_default = cur_year - 1 if now.month <= 6 else cur_year

        anni = list(MovimentoPrimaNota.objects.dates('data', 'year').values_list('data__year', flat=True))
        anni = sorted(list(set([y for y in anni if y >= 2024])), reverse=True)
        if anno_default not in anni:
            anni.insert(0, anno_default)

        asd = ConfigurazioneASD.get_instance()
        pres = MembroDirettivo.objects.filter(ruolo='presidente').first()
        vice = MembroDirettivo.objects.filter(ruolo='vicepresidente').first()
        seg = MembroDirettivo.objects.filter(ruolo='segretario').first()

        gd_config = GoogleDriveConfig.get_instance()
        tmpl = DocumentTemplate.objects.filter(chiave='verbale_rendiconto').first()
        has_tmpl = bool(tmpl and tmpl.file and os.path.exists(tmpl.file.path))
        if not has_tmpl:
            from django.conf import settings
            has_tmpl = os.path.exists(os.path.join(settings.MEDIA_ROOT, 'templates_pdf', 'Verbale.pdf'))

        return Response({
            'success': True,
            'anno_esercizio_default': anno_default,
            'anni_disponibili': anni,
            'data_assemblea_default': now.strftime('%Y-%m-%d'),
            'orario_assemblea_default': '20:00',
            'data_affissione_default': (now - datetime.timedelta(days=15)).strftime('%Y-%m-%d'),
            'presidente': pres.nome_completo if pres else '',
            'has_firma_presidente': bool(pres and pres.firma and os.path.exists(pres.firma.path)),
            'vicepresidente': vice.nome_completo if vice else '',
            'has_firma_vicepresidente': bool(vice and vice.firma and os.path.exists(vice.firma.path)),
            'segretario': seg.nome_completo if seg else '',
            'has_firma_segretario': bool(seg and seg.firma and os.path.exists(seg.firma.path)),
            'sede_legale': asd.sede_legale or '',
            'google_drive_configured': gd_config.is_configured,
            'google_drive_folder_id': gd_config.folder_verbali_id or gd_config.folder_id,
            'google_drive_folder_nome': gd_config.folder_verbali_nome or gd_config.folder_ricevute_nome or 'Predefinita',
            'has_template_verbale': has_tmpl,
        })

    @action(detail=False, methods=['post'], url_path='genera-verbale')
    def genera_verbale(self, request):
        """
        Genera il verbale compilato in formato PDF dai parametri inviati dal form.
        """
        data_assemblea = request.data.get('data_assemblea')
        orario_assemblea = request.data.get('orario_assemblea')
        data_affissione = request.data.get('data_affissione_convocazione')
        anno_esercizio = request.data.get('anno_esercizio')

        if not data_assemblea:
            return Response({'success': False, 'error': 'Il campo "Data assemblea" è obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        if not orario_assemblea:
            return Response({'success': False, 'error': 'Il campo "Orario assemblea" è obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)
        if not data_affissione:
            return Response({'success': False, 'error': 'Il campo "Data affissione convocazione" è obbligatorio.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            from .pdf_template_service import genera_pdf_verbale_rendiconto
            pdf_bytes, filename, info = genera_pdf_verbale_rendiconto(
                data_assemblea=data_assemblea,
                orario_assemblea=orario_assemblea,
                data_affissione=data_affissione,
                anno_esercizio=anno_esercizio
            )
            response = HttpResponse(pdf_bytes, content_type='application/pdf')
            response['Content-Disposition'] = f'inline; filename="{filename}"'
            response['X-Filename'] = filename
            return response
        except Exception as e:
            return Response({'success': False, 'error': f"Errore generazione verbale: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='upload-verbale-drive')
    def upload_verbale_drive(self, request):
        """
        Genera il verbale e lo carica direttamente nella cartella Verbali di Google Drive.
        """
        data_assemblea = request.data.get('data_assemblea')
        orario_assemblea = request.data.get('orario_assemblea')
        data_affissione = request.data.get('data_affissione_convocazione')
        anno_esercizio = request.data.get('anno_esercizio')

        if not data_assemblea or not orario_assemblea or not data_affissione:
            return Response({'success': False, 'error': 'Tutti i campi (Data, Orario e Data affissione) sono obbligatori.'}, status=status.HTTP_400_BAD_REQUEST)

        config = GoogleDriveConfig.get_instance()
        if not config.is_configured:
            return Response({
                'success': False,
                'error': 'Google Drive non configurato. Vai in Impostazioni > Google Drive per collegare il tuo account.'
            }, status=status.HTTP_400_BAD_REQUEST)

        target_folder_id = config.folder_verbali_id or config.folder_id
        if not target_folder_id:
            return Response({
                'success': False,
                'error': 'Nessuna cartella di destinazione impostata per i Verbali. Selezionala in Impostazioni > Google Drive.'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            from .pdf_template_service import genera_pdf_verbale_rendiconto
            pdf_bytes, filename, info = genera_pdf_verbale_rendiconto(
                data_assemblea=data_assemblea,
                orario_assemblea=orario_assemblea,
                data_affissione=data_affissione,
                anno_esercizio=anno_esercizio
            )

            from googleapiclient.http import MediaIoBaseUpload
            import io

            drive_service = get_google_drive_service(config)

            file_metadata = {
                'name': filename,
                'parents': [target_folder_id],
                'description': f"Verbale di approvazione rendiconto {info['anno_esercizio']} redatto in data {info['data_assemblea']}"
            }

            media = MediaIoBaseUpload(io.BytesIO(pdf_bytes), mimetype='application/pdf', resumable=True)
            uploaded_file = drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, name, webViewLink',
                supportsAllDrives=True
            ).execute()

            folder_nome = config.folder_verbali_nome or config.folder_ricevute_nome or 'Google Drive'

            return Response({
                'success': True,
                'message': f"Verbale caricato con successo su Google Drive nella cartella '{folder_nome}'!",
                'file_id': uploaded_file.get('id'),
                'filename': uploaded_file.get('name'),
                'webViewLink': uploaded_file.get('webViewLink'),
                'folder_nome': folder_nome,
                'info': info
            })
        except Exception as e:
            return Response({'success': False, 'error': f"Errore caricamento su Google Drive: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MembroDirettivoViewSet(viewsets.ModelViewSet):
    """
    Gestione anagrafiche dei membri del direttivo (Presidente, Vicepresidente, Segretario)
    e caricamento della loro firma autografa.
    """
    queryset = MembroDirettivo.objects.all().order_by('ordine', 'ruolo')
    serializer_class = MembroDirettivoSerializer
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        MembroDirettivo.ensure_defaults()
        return super().list(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='upload-firma')
    def upload_firma(self, request, pk=None):
        """Carica l'immagine della firma per il membro del direttivo specificato."""
        membro = self.get_object()
        file_obj = request.FILES.get('firma') or request.FILES.get('file')
        if not file_obj:
            return Response({'success': False, 'error': 'Nessun file immagine fornito.'}, status=status.HTTP_400_BAD_REQUEST)

        # Rimuovi l'eventuale file precedente
        if membro.firma:
            try:
                membro.firma.delete(save=False)
            except Exception:
                pass

        membro.firma = file_obj
        membro.save()

        serializer = self.get_serializer(membro)
        return Response({
            'success': True,
            'message': f'Firma caricata con successo per {membro.get_ruolo_display()}.',
            'membro': serializer.data
        })

    @action(detail=True, methods=['post', 'delete'], url_path='remove-firma')
    def remove_firma(self, request, pk=None):
        """Rimuove l'immagine della firma del membro del direttivo specificato."""
        membro = self.get_object()
        if membro.firma:
            try:
                membro.firma.delete(save=False)
            except Exception:
                pass
            membro.firma = None
            membro.save()

        serializer = self.get_serializer(membro)
        return Response({
            'success': True,
            'message': f'Firma rimossa con successo per {membro.get_ruolo_display()}.',
            'membro': serializer.data
        })

    @action(detail=True, methods=['get'], url_path='firma-file', permission_classes=[permissions.AllowAny])
    def firma_file(self, request, pk=None):
        """Serve l'immagine della firma associata al membro."""
        import os
        membro = self.get_object()
        if not membro.firma or not membro.firma.name:
            raise Http404("Nessuna firma presente per questo membro.")
        try:
            filename = os.path.basename(membro.firma.name)
            ext = os.path.splitext(filename)[1].lower()
            ct = 'image/png' if ext == '.png' else ('image/jpeg' if ext in ['.jpg', '.jpeg'] else 'image/png')
            return FileResponse(membro.firma.open('rb'), content_type=ct, filename=filename)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)







# ─── 2.5 Export / Download Pacchetto Mobile APK ───────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_apk_info(request):
    """Restituisce informazioni sulla disponibilità del file APK Android generato."""
    import os
    from django.conf import settings

    candidate_paths = [
        os.path.join(settings.BASE_DIR, 'flutter_app', 'build', 'app', 'outputs', 'apk', 'release', 'app-release.apk'),
        os.path.join(settings.BASE_DIR, 'flutter_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'),
    ]
    for apk_path in candidate_paths:
        if os.path.exists(apk_path):
            stat = os.stat(apk_path)
            size_mb = round(stat.st_size / (1024 * 1024), 1)
            modified_dt = datetime.datetime.fromtimestamp(stat.st_mtime).strftime('%d/%m/%Y %H:%M')
            return Response({
                'available': True,
                'filename': 'TantoTango-Manager.apk',
                'size_bytes': stat.st_size,
                'size_mb': size_mb,
                'modified_at': modified_dt,
                'download_url': '/api/app/download-apk/',
            })
    return Response({
        'available': False,
        'message': 'File APK non ancora generato sul server.',
    })


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def download_mobile_apk(request):
    """Scarica il file APK dell'app Android TantoTango Manager."""
    import os
    from django.conf import settings

    candidate_paths = [
        os.path.join(settings.BASE_DIR, 'flutter_app', 'build', 'app', 'outputs', 'apk', 'release', 'app-release.apk'),
        os.path.join(settings.BASE_DIR, 'flutter_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'),
    ]
    for apk_path in candidate_paths:
        if os.path.exists(apk_path):
            response = FileResponse(
                open(apk_path, 'rb'),
                as_attachment=True,
                filename='TantoTango-Manager.apk',
                content_type='application/vnd.android.package-archive',
            )
            return response
    raise Http404("File APK non trovato sul server.")
