from django.contrib import admin
from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione,
    Presenza, Pagamento, MessageTemplate, MessageLog, Match, RecurringSchedule
)


@admin.register(Scuola)
class ScuolaAdmin(admin.ModelAdmin):
    list_display = ('nome', 'sede', 'gruppo_whatsapp')
    search_fields = ('nome', 'sede')


@admin.register(Corso)
class CorsoAdmin(admin.ModelAdmin):
    list_display = ('scuola', 'livello', 'orario', 'anno_accademico', 'gruppo_whatsapp')
    list_filter = ('scuola', 'livello', 'anno_accademico')
    search_fields = ('scuola__nome', 'anno_accademico')


@admin.register(Argomento)
class ArgomentoAdmin(admin.ModelAdmin):
    list_display = ('titolo', 'livello', 'descrizione')
    list_filter = ('livello',)
    search_fields = ('titolo', 'descrizione')


@admin.register(Allievo)
class AllievoAdmin(admin.ModelAdmin):
    list_display = ('cognome', 'nome', 'ruolo', 'livello', 'telefono', 'corso', 'recensione', 'is_active', 'is_prospect')
    list_filter = ('ruolo', 'livello', 'is_active', 'is_prospect', 'recensione', 'corso__scuola', 'corso')
    search_fields = ('nome', 'cognome', 'telefono')


@admin.register(Jolly)
class JollyAdmin(admin.ModelAdmin):
    list_display = ('allievo', 'priorita')
    list_filter = ('priorita',)
    search_fields = ('allievo__nome', 'allievo__cognome')


@admin.register(Lezione)
class LezioneAdmin(admin.ModelAdmin):
    list_display = ('corso', 'data', 'argomento')
    list_filter = ('corso__scuola', 'corso', 'data', 'argomento')
    date_hierarchy = 'data'


@admin.register(Presenza)
class PresenzaAdmin(admin.ModelAdmin):
    list_display = ('allievo', 'lezione', 'presente', 'timestamp')
    list_filter = ('presente', 'lezione__corso__scuola', 'lezione__corso')
    search_fields = ('allievo__nome', 'allievo__cognome')


@admin.register(Pagamento)
class PagamentoAdmin(admin.ModelAdmin):
    list_display = ('allievo', 'corso', 'importo', 'trimestre', 'data_pagamento')
    list_filter = ('trimestre', 'corso__scuola', 'corso')
    search_fields = ('allievo__nome', 'allievo__cognome')
    date_hierarchy = 'data_pagamento'


@admin.register(MessageTemplate)
class MessageTemplateAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name', 'body')


@admin.register(MessageLog)
class MessageLogAdmin(admin.ModelAdmin):
    list_display = ('lezione', 'template', 'status', 'timestamp')
    list_filter = ('status',)
    search_fields = ('rendered_text', 'error_message')


@admin.register(Match)
class MatchAdmin(admin.ModelAdmin):
    list_display = ('lezione', 'leader', 'follower', 'is_rotation')
    list_filter = ('lezione__corso', 'is_rotation')


@admin.register(RecurringSchedule)
class RecurringScheduleAdmin(admin.ModelAdmin):
    list_display = ('corso', 'days_of_week', 'time', 'rsvp_mode', 'debug_mode')
    list_filter = ('rsvp_mode', 'debug_mode')

