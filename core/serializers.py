from rest_framework import serializers
from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule
)


class ScuolaSerializer(serializers.ModelSerializer):
    corsi_count = serializers.IntegerField(source='corsi.count', read_only=True)

    class Meta:
        model = Scuola
        fields = ['id', 'nome', 'sede', 'gruppo_whatsapp', 'corsi_count']


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

    class Meta:
        model = Allievo
        fields = [
            'id', 'nome', 'cognome', 'ruolo', 'ruolo_display',
            'telefono', 'corso', 'corso_descrizione', 'scuola_id', 'scuola_nome',
            'recensione', 'recensione_display', 'livello', 'livello_display',
            'is_active', 'is_prospect', 'note', 'partner', 'partner_nome', 'partner_cognome'
        ]

    def get_corso_descrizione(self, obj):
        if obj.corso:
            return f"{obj.corso.scuola.nome} - {obj.corso.get_livello_display()} ({obj.corso.orario.strftime('%H:%M')})"
        return None


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
    allievo_nome = serializers.CharField(source='allievo.__str__', read_only=True)
    allievo_ruolo = serializers.CharField(source='allievo.ruolo', read_only=True)
    allievo_telefono = serializers.CharField(source='allievo.telefono', read_only=True)
    allievo_is_prospect = serializers.BooleanField(source='allievo.is_prospect', read_only=True)
    allievo_partner_id = serializers.UUIDField(source='allievo.partner.id', read_only=True)
    allievo_partner_nome = serializers.CharField(source='allievo.partner.__str__', read_only=True)
    lezione_data = serializers.DateField(source='lezione.data', read_only=True)

    class Meta:
        model = Presenza
        fields = [
            'id', 'lezione', 'lezione_data', 'allievo',
            'allievo_nome', 'allievo_ruolo', 'allievo_telefono', 'allievo_is_prospect', 'allievo_partner_id', 'allievo_partner_nome',
            'presente', 'fonte', 'timestamp'
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
