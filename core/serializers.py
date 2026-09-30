from rest_framework import serializers
from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule
)
from .wa_client import resolve_group_link


def normalize_and_resolve_whatsapp_group(value: str) -> str:
    """
    Se l'utente fornisce un link di invito (es. https://chat.whatsapp.com/...)
    o un codice d'invito WhatsApp, interroga il Gateway per risalire al JID reale
    del gruppo (es. 120363... @g.us) prima del salvataggio.
    """
    val = (value or '').strip()
    if not val:
        return ''

    # Rimuovi query parameter se presenti (es. ?mode=...)
    if '?' in val:
        val = val.split('?')[0].trim()

    # Se è già un JID reale numerico (es. 120363421055382619@g.us o con trattino -)
    clean_val = val.replace('@g.us', '').strip()
    is_real_jid = (clean_val.startswith('120363') and clean_val.isdigit()) or ('-' in clean_val and not clean_val.startswith('http'))
    if is_real_jid:
        return val if val.endswith('@g.us') else f"{clean_val}@g.us"

    # Altrimenti risali al gruppo tramite link o codice d'invito
    res = resolve_group_link(val)
    if res.get('success') and res.get('groupId'):
        return res['groupId']

    err_msg = res.get('error') or "Impossibile risalire al gruppo WhatsApp dal link d'invito fornito. Verifica che sia valido e attivo."
    raise serializers.ValidationError(err_msg)


class ScuolaSerializer(serializers.ModelSerializer):
    corsi_count = serializers.IntegerField(source='corsi.count', read_only=True)

    class Meta:
        model = Scuola
        fields = ['id', 'nome', 'sede', 'gruppo_whatsapp', 'corsi_count']

    def validate_gruppo_whatsapp(self, value):
        return normalize_and_resolve_whatsapp_group(value)



class CorsoSerializer(serializers.ModelSerializer):
    scuola_nome = serializers.CharField(source='scuola.nome', read_only=True)
    scuola_sede = serializers.CharField(source='scuola.sede', read_only=True)
    livello_display = serializers.CharField(source='get_livello_display', read_only=True)
    giorno_settimana_display = serializers.CharField(source='get_giorno_settimana_display', read_only=True)
    allievi_count = serializers.IntegerField(source='allievi.count', read_only=True)

    class Meta:
        model = Corso
        fields = [
            'id', 'scuola', 'scuola_nome', 'scuola_sede', 'livello',
            'livello_display', 'giorno_settimana', 'giorno_settimana_display',
            'orario', 'anno_accademico', 'gruppo_whatsapp', 'allievi_count'
        ]

    def to_internal_value(self, data):
        if isinstance(data, dict) and 'giorno_settimana' in data and data['giorno_settimana']:
            val = str(data['giorno_settimana']).strip().upper()
            mapping = {
                'LUNEDÌ': 'LUNEDI',
                'LUNEDI': 'LUNEDI',
                'MARTEDÌ': 'MARTEDI',
                'MARTEDI': 'MARTEDI',
                'MERCOLEDÌ': 'MERCOLEDI',
                'MERCOLEDI': 'MERCOLEDI',
                'GIOVEDÌ': 'GIOVEDI',
                'GIOVEDI': 'GIOVEDI',
                'VENERDÌ': 'VENERDI',
                'VENERDI': 'VENERDI',
                'SABATO': 'SABATO',
                'DOMENICA': 'DOMENICA',
            }
            data = data.copy()
            data['giorno_settimana'] = mapping.get(val, val)
        return super().to_internal_value(data)

    def validate_gruppo_whatsapp(self, value):
        return normalize_and_resolve_whatsapp_group(value)



class ArgomentoSerializer(serializers.ModelSerializer):
    livello_display = serializers.CharField(source='get_livello_display', read_only=True)

    class Meta:
        model = Argomento
        fields = ['id', 'titolo', 'descrizione', 'livello', 'livello_display']


class AllievoSerializer(serializers.ModelSerializer):
    corso_descrizione = serializers.SerializerMethodField()
    scuola_id = serializers.UUIDField(source='corso.scuola.id', read_only=True)
    scuola_nome = serializers.CharField(source='corso.scuola.nome', read_only=True)
    ruolo_display = serializers.CharField(source='get_ruolo_display', read_only=True)
    livello_display = serializers.CharField(source='get_livello_display', read_only=True)
    recensione_display = serializers.CharField(source='get_recensione_display', read_only=True)
    partner_nome = serializers.CharField(source='partner.nome', read_only=True)
    partner_cognome = serializers.CharField(source='partner.cognome', read_only=True)
    corso_gruppo_whatsapp = serializers.CharField(source='corso.gruppo_whatsapp', read_only=True)
    corso_has_whatsapp = serializers.SerializerMethodField()

    class Meta:
        model = Allievo
        fields = [
            'id', 'nome', 'cognome', 'ruolo', 'ruolo_display',
            'telefono', 'corso', 'corso_descrizione', 'scuola_id', 'scuola_nome',
            'recensione', 'recensione_display', 'livello', 'livello_display',
            'is_active', 'is_prospect', 'note', 'partner', 'partner_nome', 'partner_cognome',
            'in_gruppo_scuola_whatsapp', 'in_gruppo_corso_whatsapp',
            'corso_gruppo_whatsapp', 'corso_has_whatsapp'
        ]

    def get_corso_descrizione(self, obj):
        if obj.corso:
            return f"{obj.corso.scuola.nome} - {obj.corso.get_livello_display()} ({obj.corso.orario.strftime('%H:%M')})"
        return None

    def get_corso_has_whatsapp(self, obj):
        return bool(obj.corso and obj.corso.gruppo_whatsapp and obj.corso.gruppo_whatsapp.strip())



class JollySerializer(serializers.ModelSerializer):
    allievo_nome = serializers.CharField(source='allievo.__str__', read_only=True)
    allievo_telefono = serializers.CharField(source='allievo.telefono', read_only=True)
    allievo_ruolo = serializers.CharField(source='allievo.ruolo', read_only=True)
    allievo_ruolo_display = serializers.CharField(source='allievo.get_ruolo_display', read_only=True)
    allievo_livello = serializers.CharField(source='allievo.livello', read_only=True)

    class Meta:
        model = Jolly
        fields = [
            'id', 'allievo', 'allievo_nome', 'allievo_telefono',
            'allievo_ruolo', 'allievo_ruolo_display', 'allievo_livello', 'priorita'
        ]


class LezioneSerializer(serializers.ModelSerializer):
    corso_descrizione = serializers.SerializerMethodField()
    scuola_id = serializers.UUIDField(source='corso.scuola.id', read_only=True)
    scuola_nome = serializers.CharField(source='corso.scuola.nome', read_only=True)
    argomento_titolo = serializers.CharField(source='argomento.titolo', read_only=True)
    presenze_totali = serializers.IntegerField(source='presenze.count', read_only=True)
    presenti_count = serializers.SerializerMethodField()

    class Meta:
        model = Lezione
        fields = [
            'id', 'corso', 'corso_descrizione', 'scuola_id', 'scuola_nome',
            'data', 'titolo', 'argomento', 'argomento_titolo',
            'presenze_totali', 'presenti_count'
        ]

    def get_corso_descrizione(self, obj):
        return str(obj.corso)

    def get_presenti_count(self, obj):
        return obj.presenze.filter(presente=True).count()


class PresenzaSerializer(serializers.ModelSerializer):
    allievo_nome = serializers.SerializerMethodField()
    allievo_nome_solo = serializers.CharField(source='allievo.nome', read_only=True)
    allievo_cognome = serializers.CharField(source='allievo.cognome', read_only=True)
    allievo_ruolo = serializers.CharField(source='allievo.ruolo', read_only=True)
    allievo_telefono = serializers.CharField(source='allievo.telefono', read_only=True)
    allievo_is_prospect = serializers.BooleanField(source='allievo.is_prospect', read_only=True)
    allievo_partner_id = serializers.UUIDField(source='allievo.partner.id', read_only=True)
    allievo_partner_nome = serializers.SerializerMethodField()
    is_jolly = serializers.SerializerMethodField()

    def get_allievo_nome(self, obj):
        if obj.allievo:
            return f"{obj.allievo.nome} {obj.allievo.cognome}".strip()
        return ""

    def get_allievo_partner_nome(self, obj):
        if obj.allievo and obj.allievo.partner:
            return f"{obj.allievo.partner.nome} {obj.allievo.partner.cognome}".strip()
        return None

    def get_is_jolly(self, obj):
        return bool(getattr(obj, 'is_jolly', False))

    lezione_data = serializers.DateField(source='lezione.data', read_only=True)

    class Meta:
        model = Presenza
        fields = [
            'id', 'lezione', 'lezione_data', 'allievo',
            'allievo_nome', 'allievo_nome_solo', 'allievo_cognome',
            'allievo_ruolo', 'allievo_telefono', 'allievo_is_prospect',
            'allievo_partner_id', 'allievo_partner_nome',
            'is_jolly', 'presente', 'fonte', 'timestamp'
        ]


class PagamentoSerializer(serializers.ModelSerializer):
    allievo_nome = serializers.CharField(source='allievo.__str__', read_only=True)
    corso_descrizione = serializers.CharField(source='corso.__str__', read_only=True)
    scuola_id = serializers.UUIDField(source='corso.scuola.id', read_only=True)
    scuola_nome = serializers.CharField(source='corso.scuola.nome', read_only=True)
    trimestre_display = serializers.CharField(source='get_trimestre_display', read_only=True)

    class Meta:
        model = Pagamento
        fields = [
            'id', 'allievo', 'allievo_nome', 'corso', 'corso_descrizione',
            'scuola_id', 'scuola_nome', 'importo', 'trimestre',
            'trimestre_display', 'data_pagamento', 'note'
        ]


class MessageTemplateSerializer(serializers.ModelSerializer):
    class Meta:
        model = MessageTemplate
        fields = ['id', 'name', 'body']


class MessageLogSerializer(serializers.ModelSerializer):
    template_name = serializers.CharField(source='template.name', read_only=True)
    lezione_data = serializers.DateField(source='lezione.data', read_only=True)

    class Meta:
        model = MessageLog
        fields = [
            'id', 'lezione', 'lezione_data', 'template', 'template_name',
            'status', 'rendered_text', 'error_message', 'timestamp'
        ]


class MatchSerializer(serializers.ModelSerializer):
    leader_nome = serializers.CharField(source='leader.__str__', read_only=True)
    follower_nome = serializers.CharField(source='follower.__str__', read_only=True)

    class Meta:
        model = Match
        fields = [
            'id', 'lezione', 'leader', 'leader_nome',
            'follower', 'follower_nome', 'is_rotation'
        ]


class RecurringScheduleSerializer(serializers.ModelSerializer):
    corso_descrizione = serializers.CharField(source='corso.__str__', read_only=True)

    class Meta:
        model = RecurringSchedule
        fields = [
            'id', 'corso', 'corso_descrizione', 'days_of_week', 'time',
            'start_date', 'end_date', 'rsvp_days_before', 'rsvp_time',
            'match_days_before', 'match_time', 'rsvp_mode',
            'gemini_api_key', 'debug_mode'
        ]
