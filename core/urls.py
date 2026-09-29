from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views
from . import api_views
from . import import_export

app_name = 'core'

# DRF Router per le ViewSets REST
router = DefaultRouter()
router.register(r'scuole', api_views.ScuolaViewSet, basename='scuola')
router.register(r'corsi', api_views.CorsoViewSet, basename='corso')
router.register(r'argomenti', api_views.ArgomentoViewSet, basename='argomento')
router.register(r'allievi', api_views.AllievoViewSet, basename='allievo')
router.register(r'jolly', api_views.JollyViewSet, basename='jolly')
router.register(r'lezioni', api_views.LezioneViewSet, basename='lezione')
router.register(r'presenze', api_views.PresenzaViewSet, basename='presenza')
router.register(r'pagamenti', api_views.PagamentoViewSet, basename='pagamento')
router.register(r'templates', api_views.MessageTemplateViewSet, basename='template')
router.register(r'logs', api_views.MessageLogViewSet, basename='log')
router.register(r'matches', api_views.MatchViewSet, basename='match')
router.register(r'schedules', api_views.RecurringScheduleViewSet, basename='schedule')

urlpatterns = [
    # 2.1 Autenticazione API
    path('api/auth/login/', api_views.api_login, name='api_login'),
    path('api/auth/logout/', api_views.api_logout, name='api_logout'),
    path('api/auth/user/', api_views.api_current_user, name='api_current_user'),

    # 2.4 Invio messaggi Jolly
    path('api/jolly/send-message/', api_views.send_jolly_message, name='api_send_jolly_message'),

    # 5.1 Export API
    path('api/export/global/', import_export.export_global, name='export_global'),
    path('api/export/allievi/', import_export.export_allievi, name='export_allievi'),
    path('api/export/presenze/', import_export.export_presenze, name='export_presenze'),
    path('api/export/pagamenti/', import_export.export_pagamenti, name='export_pagamenti'),
    path('api/export/lezioni/', import_export.export_lezioni, name='export_lezioni'),

    # 5.2 Template Import API
    path('api/import/template/<str:model_name>/', import_export.get_import_template, name='get_import_template'),

    # 5.1 Import API
    path('api/import/global/', import_export.import_global, name='import_global'),
    path('api/import/allievi/', import_export.import_allievi, name='import_allievi'),
    path('api/import/presenze/', import_export.import_presenze, name='import_presenze'),
    path('api/import/pagamenti/', import_export.import_pagamenti, name='import_pagamenti'),

    # Router REST API
    path('api/', include(router.urls)),

    # Viste Web & Dashboard esistenti
    path('', views.dashboard, name='dashboard'),
    path('rsvp/<str:event_id>/', views.rsvp_view, name='rsvp'),
    path('onboarding/', views.onboarding, name='onboarding'),
    path('api/wa-status/', views.wa_status, name='wa_status'),
    path('api/wa-logout/', views.wa_logout, name='wa_logout'),
    path('api/webhook/poll-vote/', views.poll_vote_webhook, name='poll_vote_webhook'),

    # Viste legacy per dashboard html
    path('api/update-group/', views.update_group, name='update_group'),
    path('api/update-templates/', views.update_templates, name='update_templates'),
    path('api/update-scheduling/', views.update_scheduling, name='update_scheduling'),
    path('api/update-recurring/', views.update_recurring, name='update_recurring'),
    path('api/trigger-rsvp/', views.trigger_rsvp, name='trigger_rsvp'),
    path('api/trigger-match/', views.trigger_match, name='trigger_match'),
    path('api/participants/', views.list_participants, name='list_participants'),
    path('api/participants/save/', views.save_participant, name='save_participant'),
    path('api/participants/delete/', views.delete_participant, name='delete_participant'),
]
