from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule
)
from .serializers import (
    ScuolaSerializer, CorsoSerializer, ArgomentoSerializer,
    AllievoSerializer, JollySerializer, LezioneSerializer,
    PresenzaSerializer, PagamentoSerializer, MessageTemplateSerializer,
    MessageLogSerializer, MatchSerializer, RecurringScheduleSerializer
)
from .services import generate_matches
from .wa_client import send_whatsapp_message


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
    filterset_fields = ['corso', 'corso__scuola', 'is_prospect', 'ruolo', 'livello', 'recensione', 'is_active']
    search_fields = ['nome', 'cognome', 'telefono', 'note']
    ordering_fields = ['cognome', 'nome', 'livello', 'ruolo']

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
        allievo.is_prospect = False
        allievo.save()
        return Response(self.get_serializer(allievo).data)


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
        """Restituisce le presenze per la lezione selezionata."""
        lezione = self.get_object()
        presenze = Presenza.objects.filter(lezione=lezione).select_related('allievo')
        serializer = PresenzaSerializer(presenze, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def init_presenze(self, request, pk=None):
        """Inizializza le presenze per tutti gli allievi (effettivi e prospect) del corso della lezione."""
        lezione = self.get_object()
        allievi = Allievo.objects.filter(corso=lezione.corso, is_active=True)
        created_count = 0
        for allievo in allievi:
            _, created = Presenza.objects.get_or_create(
                lezione=lezione,
                allievo=allievo,
                defaults={'presente': False}
            )
            if created:
                created_count += 1
        return Response({
            'message': f'Inizializzate {created_count} presenze per {allievi.count()} partecipanti del corso.'
        })

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
    search_fields = ['allievo__nome', 'allievo__cognome', 'corso__scuola__nome', 'note']
    ordering_fields = ['data_pagamento', 'importo']


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
