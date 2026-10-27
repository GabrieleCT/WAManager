import uuid
from django.db import models
from django.db.models.signals import pre_delete
from django.dispatch import receiver
from django.utils import timezone


# ─── Enumerazioni ───────────────────────────────────────────────

class Role(models.TextChoices):
    LEADER = 'leader', 'Leader'
    FOLLOWER = 'follower', 'Follower'
    BOTH = 'both', 'Entrambi'


class Level(models.TextChoices):
    PRINCIPIANTE = 'principiante', 'Principiante'
    INTERMEDIO = 'intermedio', 'Intermedio'
    AVANZATO = 'avanzato', 'Avanzato'


class Recensione(models.TextChoices):
    SI = 'si', 'Sì'
    NO = 'no', 'No'


class Trimestre(models.TextChoices):
    PRIMO = 'T1', 'Primo Trimestre'
    SECONDO = 'T2', 'Secondo Trimestre'
    TERZO = 'T3', 'Terzo Trimestre'


# ─── 1.2 Scuola ─────────────────────────────────────────────────

class Scuola(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nome = models.CharField(max_length=200)
    sede = models.CharField(max_length=300)
    gruppo_whatsapp = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text="ID o nome del gruppo WhatsApp della scuola (es. 123456@g.us)"
    )

    class Meta:
        verbose_name_plural = 'Scuole'
        ordering = ['nome']

    def __str__(self):
        return f"{self.nome} ({self.sede})"


# ─── 1.3 Corso ──────────────────────────────────────────────────

class Corso(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    scuola = models.ForeignKey(Scuola, on_delete=models.CASCADE, related_name='corsi')
    livello = models.CharField(max_length=20, choices=Level.choices, default=Level.PRINCIPIANTE)
    GIORNI_SETTIMANA = [
        ('LUNEDI', 'Lunedì'),
        ('MARTEDI', 'Martedì'),
        ('MERCOLEDI', 'Mercoledì'),
        ('GIOVEDI', 'Giovedì'),
        ('VENERDI', 'Venerdì'),
        ('SABATO', 'Sabato'),
        ('DOMENICA', 'Domenica'),
    ]
    giorno_settimana = models.CharField(max_length=15, choices=GIORNI_SETTIMANA, default='LUNEDI')
    orario = models.TimeField(help_text="Orario della lezione")
    anno_accademico = models.CharField(max_length=20, default='2025/2026', help_text="Anno accademico (es. 2025/2026)")
    gruppo_whatsapp = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text="ID o nome del gruppo WhatsApp del corso (es. 123456@g.us)"
    )

    class Meta:
        verbose_name_plural = 'Corsi'
        ordering = ['scuola__nome', 'livello']

    @property
    def nome(self):
        return f"{self.scuola.nome} - {self.get_livello_display()}"

    def __str__(self):
        return f"{self.scuola.nome} - {self.get_livello_display()} ({self.orario.strftime('%H:%M')}) [{self.anno_accademico}]"



# ─── 1.5 Argomento ──────────────────────────────────────────────

class Argomento(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    titolo = models.CharField(max_length=200)
    descrizione = models.TextField(blank=True, default='')
    livello = models.CharField(max_length=20, choices=Level.choices, default=Level.PRINCIPIANTE)
    ordine = models.PositiveIntegerField(default=0, db_index=True)

    class Meta:
        verbose_name_plural = 'Argomenti'
        ordering = ['ordine', 'titolo']

    def save(self, *args, **kwargs):
        if self._state.adding and (self.ordine is None or self.ordine == 0):
            max_o = Argomento.objects.aggregate(max_o=models.Max('ordine'))['max_o']
            self.ordine = ((max_o or 0) + 1) if max_o is not None else 1
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.titolo} ({self.get_livello_display()})"


# ─── 1.1 Allievo (include Prospect con flag is_prospect) ─────────

class Allievo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nome = models.CharField(max_length=100)
    cognome = models.CharField(max_length=100)
    ruolo = models.CharField(max_length=10, choices=Role.choices, default=Role.LEADER)
    telefono = models.CharField(max_length=20, blank=True, default='')
    corso = models.ForeignKey(
        Corso,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='allievi',
        help_text="Corso di appartenenza (vuoto per prospect)"
    )
    recensione = models.CharField(max_length=2, choices=Recensione.choices, default=Recensione.NO)
    livello = models.CharField(max_length=20, choices=Level.choices, default=Level.PRINCIPIANTE)
    is_active = models.BooleanField(default=True)
    is_prospect = models.BooleanField(
        default=False,
        help_text="Se True, è un prospect (non ancora iscritto a un corso)"
    )
    note = models.TextField(
        blank=True,
        default='',
        help_text="Note aggiuntive (usato principalmente per prospect)"
    )
    partner = models.OneToOneField(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        help_text="Partner di ballo dell'allievo"
    )
    in_gruppo_scuola_whatsapp = models.BooleanField(
        default=False,
        help_text="Indica se l'allievo è presente nel gruppo WhatsApp della Scuola"
    )
    in_gruppo_corso_whatsapp = models.BooleanField(
        default=False,
        help_text="Indica se l'allievo è presente nel gruppo WhatsApp del Corso"
    )
    numero_tessera = models.CharField(
        max_length=50,
        blank=True,
        default='',
        help_text="Numero della tessera dell'allievo"
    )
    data_emissione_tessera = models.DateField(
        null=True,
        blank=True,
        help_text="Data di emissione della tessera"
    )
    email = models.EmailField(
        max_length=254,
        blank=True,
        default='',
        help_text="Indirizzo email dell'allievo/prospect"
    )
    google_contact_id = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Resource Name del contatto in Google Contacts (People API)"
    )
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)

    @property
    def stato_tessera(self):
        if not self.numero_tessera or not self.numero_tessera.strip() or not self.data_emissione_tessera:
            return 'NON TESSERATO'
        from datetime import date, timedelta
        today = date.today()
        try:
            scadenza = self.data_emissione_tessera.replace(year=self.data_emissione_tessera.year + 1)
        except ValueError:
            scadenza = self.data_emissione_tessera + timedelta(days=365)
        if today > scadenza:
            return 'TESSERA SCADUTA'
        return 'TESSERA OK'

    class Meta:
        verbose_name_plural = 'Allievi'
        ordering = ['cognome', 'nome']

    def __str__(self):
        prefix = "[Prospect] " if self.is_prospect else ""
        return f"{prefix}{self.nome} {self.cognome}"

    def save(self, *args, **kwargs):
        vecchio_corso_id = None
        if self.pk:
            old_inst = Allievo.objects.filter(pk=self.pk).values('corso_id', 'livello').first()
            if old_inst:
                vecchio_corso_id = old_inst['corso_id']

        if self.corso:
            if self.corso.livello != self.livello:
                matching_corso = Corso.objects.filter(scuola=self.corso.scuola, livello=self.livello).first()
                if matching_corso:
                    self.corso = matching_corso
                else:
                    self.livello = self.corso.livello
            else:
                self.livello = self.corso.livello

        super().save(*args, **kwargs)

        from django.apps import apps
        Presenza = apps.get_model('core', 'Presenza')
        Lezione = apps.get_model('core', 'Lezione')

        if vecchio_corso_id and self.corso_id and str(vecchio_corso_id) != str(self.corso_id):
            # Rimuovi le presenze del vecchio corso (a meno che non siano presenze registrate come jolly)
            Presenza.objects.filter(
                allievo=self,
                lezione__corso_id=vecchio_corso_id,
                is_jolly=False
            ).delete()

            # Inizializza presenze per le lezioni del nuovo corso
            for lez in Lezione.objects.filter(corso_id=self.corso_id):
                Presenza.objects.get_or_create(
                    lezione=lez,
                    allievo=self,
                    defaults={'presente': False, 'fonte': 'manuale', 'is_jolly': False}
                )
        elif not vecchio_corso_id and self.corso_id:
            for lez in Lezione.objects.filter(corso_id=self.corso_id):
                Presenza.objects.get_or_create(
                    lezione=lez,
                    allievo=self,
                    defaults={'presente': False, 'fonte': 'manuale', 'is_jolly': False}
                )
        elif vecchio_corso_id and not self.corso_id:
            Presenza.objects.filter(
                allievo=self,
                lezione__corso_id=vecchio_corso_id,
                is_jolly=False
            ).delete()


@receiver(pre_delete, sender=Allievo)
def allievo_pre_delete_cleanup(sender, instance, **kwargs):
    """
    All'eliminazione di un allievo (da qualsiasi punto del gestionale):
    1. Rimuove l'allievo dai gruppi WhatsApp (corso e scuola)
    2. Elimina la chat WhatsApp individuale
    3. Elimina il contatto dalla Rubrica Google (Google Contacts)
    """
    if getattr(instance, '_skip_pre_delete_cleanup', False):
        return
    try:
        from .services import cleanup_allievo_on_deletion
        cleanup_allievo_on_deletion(instance)
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Errore pre_delete cleanup per allievo {instance.id}: {e}")



# ─── 1.4 Jolly ──────────────────────────────────────────────────

class Jolly(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    allievo = models.ForeignKey(Allievo, on_delete=models.CASCADE, related_name='jolly_entries')
    nickname = models.CharField(max_length=100, blank=True, default='', help_text="Nickname del jolly")
    priorita = models.PositiveIntegerField(default=1, help_text="1 = priorità più alta")

    class Meta:
        verbose_name_plural = 'Jolly'
        ordering = ['priorita']

    def save(self, *args, **kwargs):
        if not self.nickname or not self.nickname.strip():
            if self.allievo and self.allievo.nome:
                self.nickname = self.allievo.nome.strip()
            else:
                self.nickname = ""
        else:
            self.nickname = self.nickname.strip()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Jolly: {self.nickname or self.allievo} (priorità {self.priorita})"


# ─── 1.6 Lezione ────────────────────────────────────────────────

class Lezione(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    corso = models.ForeignKey(Corso, on_delete=models.CASCADE, related_name='lezioni')
    data = models.DateField()
    titolo = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text="Titolo o convenzione (es. 1/12 - 1° Trimestre)"
    )
    argomento = models.ForeignKey(
        Argomento,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='lezioni',
        help_text="Argomento trattato nella lezione"
    )

    class Meta:
        verbose_name_plural = 'Lezioni'
        ordering = ['-data']

    def __str__(self):
        arg_str = f" - {self.argomento.titolo}" if self.argomento else ""
        return f"{self.corso} - {self.data.strftime('%d/%m/%Y')}{arg_str}"


# ─── 1.7 Presenza ───────────────────────────────────────────────

class Presenza(models.Model):
    FONTE_CHOICES = [
        ('manuale', 'Manuale'),
        ('whatsapp', 'WhatsApp'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    lezione = models.ForeignKey(Lezione, on_delete=models.CASCADE, related_name='presenze')
    allievo = models.ForeignKey(Allievo, on_delete=models.CASCADE, related_name='presenze')
    presente = models.BooleanField(null=True, blank=True, default=None)
    fonte = models.CharField(max_length=20, choices=FONTE_CHOICES, default='manuale')
    is_jolly = models.BooleanField(default=False, help_text="Se True, è presente alla lezione come Jolly")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = 'Presenze'
        unique_together = ('lezione', 'allievo')

    def __str__(self):
        stato = '[Presente]' if self.presente else '[Assente]'
        return f"{stato} {self.allievo} - {self.lezione}"


# ─── 1.8 Pagamento ──────────────────────────────────────────────

class Pagamento(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    allievo = models.ForeignKey(Allievo, on_delete=models.CASCADE, related_name='pagamenti')
    corso = models.ForeignKey(Corso, on_delete=models.CASCADE, related_name='pagamenti')
    importo = models.DecimalField(max_digits=8, decimal_places=2, default=150.00)
    trimestre = models.CharField(max_length=2, choices=Trimestre.choices, default=Trimestre.PRIMO)
    data_pagamento = models.DateField()
    causale = models.CharField(max_length=255, blank=True, default='')
    note = models.TextField(blank=True, default='')

    class Meta:
        verbose_name_plural = 'Pagamenti'
        ordering = ['-data_pagamento']

    def __str__(self):
        causale_str = f" ({self.causale})" if self.causale else ""
        return f"{self.allievo} - {self.corso} - {self.get_trimestre_display()}{causale_str} - €{self.importo}"


# ─── WhatsApp: Template e Log messaggi ──────────────────────────

class MessageTemplate(models.Model):
    name = models.CharField(max_length=100)
    body = models.TextField(help_text="Testo del messaggio con eventuali placeholder")

    def __str__(self):
        return self.name


class MessageLog(models.Model):
    lezione = models.ForeignKey(Lezione, on_delete=models.SET_NULL, null=True, blank=True)
    template = models.ForeignKey(MessageTemplate, on_delete=models.SET_NULL, null=True, blank=True)
    status = models.CharField(max_length=50, default='Generato')
    rendered_text = models.TextField()
    error_message = models.TextField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Log {self.id} - {self.status}"


# ─── Matching coppie per lezione ────────────────────────────────

class Match(models.Model):
    lezione = models.ForeignKey(Lezione, on_delete=models.CASCADE, related_name='matches')
    leader = models.ForeignKey(
        Allievo,
        on_delete=models.CASCADE,
        related_name='leader_matches',
        null=True,
        blank=True
    )
    follower = models.ForeignKey(
        Allievo,
        on_delete=models.CASCADE,
        related_name='follower_matches',
        null=True,
        blank=True
    )
    is_rotation = models.BooleanField(
        default=False,
        help_text="True se questa persona è in rotazione a causa di disparità numerica"
    )

    class Meta:
        verbose_name_plural = 'Matches'

    def __str__(self):
        l_name = self.leader if self.leader else "Rotazione"
        f_name = self.follower if self.follower else "Rotazione"
        return f"{self.lezione.data}: {l_name} + {f_name}"


# ─── Schedulazione ricorrente (per corso o globale) ─────────────

class RecurringSchedule(models.Model):
    corso = models.ForeignKey(
        Corso,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='schedules',
        help_text="Corso a cui si applica la schedulazione (vuoto se globale)"
    )
    days_of_week = models.CharField(
        max_length=50,
        default="0",
        help_text="Giorni della settimana (0=Lun, 6=Dom) separati da virgola"
    )
    time = models.TimeField(help_text="Ora inizio evento")
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)

    rsvp_days_before = models.IntegerField(default=0)
    rsvp_time = models.TimeField(default='08:00:00')
    match_days_before = models.IntegerField(default=0)
    match_time = models.TimeField(default='19:00:00')

    RSVP_MODE_CHOICES = [
        ('POLL', 'Sondaggio (Default)'),
        ('LLM', 'Risposta Libera (Gemini AI)'),
    ]
    rsvp_mode = models.CharField(max_length=10, choices=RSVP_MODE_CHOICES, default='POLL')
    gemini_api_key = models.CharField(max_length=255, blank=True, null=True)
    debug_mode = models.BooleanField(default=True)

    gemini_monitoring_active = models.BooleanField(
        default=True,
        help_text="Attiva monitoraggio messaggi WhatsApp con Gemini"
    )
    gemini_time_start = models.TimeField(
        default='07:00:00',
        help_text="Ora inizio monitoraggio (default 07:00)"
    )
    gemini_time_end = models.TimeField(
        default='13:00:00',
        help_text="Ora fine monitoraggio (default 13:00)"
    )
    gemini_only_course_days = models.BooleanField(
        default=True,
        help_text="Monitora solo nei giorni di svolgimento del relativo corso"
    )
    gemini_custom_days = models.CharField(
        max_length=100,
        default="LUNEDI,MERCOLEDI,GIOVEDI",
        blank=True,
        help_text="Giorni abilitati separati da virgola (se non solo giorni corso)"
    )

    def __str__(self):
        corso_str = str(self.corso) if self.corso else "Globale"
        return f"{corso_str} - Giorni {self.days_of_week} alle {self.time}"

class SondaggioMattutinoConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    corso = models.ForeignKey(
        Corso,
        on_delete=models.CASCADE,
        related_name='sondaggi',
        null=True,
        blank=True,
        help_text="Corso specifico, oppure vuoto per impostazione globale predefinita"
    )
    orario = models.CharField(
        max_length=5,
        default='08:00',
        help_text="Orario invio demone nel formato HH:MM (es. 08:00)"
    )
    giorni_settimana = models.CharField(
        max_length=50,
        default='0,1,2,3,4,5,6',
        help_text="Giorni della settimana (0=Lun, 1=Mar, 2=Mer, 3=Gio, 4=Ven, 5=Sab, 6=Dom) separati da virgola"
    )
    testo = models.TextField(
        default="Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\nChi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!"
    )
    is_poll = models.BooleanField(
        default=True,
        help_text="Se True invia un sondaggio nativo WhatsApp con opzioni Sì/No, altrimenti messaggio di testo."
    )
    poll_opzione_1 = models.CharField(max_length=100, default="Ci sono! 🕺💃")
    poll_opzione_2 = models.CharField(max_length=100, default="Non ci sono 🚫")
    ore_ascolto_risposte = models.IntegerField(
        default=5,
        help_text="Ore di ascolto dell'AI (Gemini) dopo l'invio del messaggio"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Se attivo, il demone invierà automaticamente il sondaggio secondo la schedulazione."
    )
    sollecito_attivo = models.BooleanField(
        default=False,
        help_text="Se attivo, invia un messaggio di sollecito nel pomeriggio a ridosso della lezione."
    )
    sollecito_orario = models.CharField(
        max_length=5,
        default='16:00',
        help_text="Orario invio sollecito nel formato HH:MM (es. 16:00)"
    )
    sollecito_testo = models.TextField(
        default="Ciao <nome_allievo>, ci sei stasera al corso?",
        help_text="Testo del messaggio di sollecito risposta inviato all'allievo"
    )
    jolly_testo = models.TextField(
        default="Ciao! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺",
        help_text="Testo predefinito per il messaggio inviato ai Jolly"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        c_str = str(self.corso) if self.corso else "Globale"
        return f"Sondaggio {c_str} ({self.orario}) - Attivo: {self.is_active}"

class GeminiLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    timestamp = models.DateTimeField(auto_now_add=True)
    corso = models.ForeignKey(Corso, on_delete=models.SET_NULL, null=True, blank=True, related_name='gemini_logs')
    gruppo_whatsapp = models.CharField(max_length=200, blank=True, default='', help_text="JID del gruppo WhatsApp del corso")
    mittente = models.CharField(max_length=200, blank=True, default='', help_text="Nome o numero del mittente del messaggio")
    allievo = models.ForeignKey(Allievo, on_delete=models.SET_NULL, null=True, blank=True, related_name='gemini_logs')
    lezione = models.ForeignKey(Lezione, on_delete=models.SET_NULL, null=True, blank=True, related_name='gemini_logs')
    testo_originale = models.TextField(help_text="Messaggio WhatsApp ricevuto dal gruppo")
    chiamata_ai = models.TextField(blank=True, default='', help_text="Prompt/chiamata inviata a Gemini")
    risposta_ai = models.TextField(blank=True, default='', help_text="Risposta grezza restituita da Gemini")
    esito_interpretato = models.CharField(max_length=50) # PRESENTE_SINGOLO, PRESENTE_COPPIA, ASSENTE_SINGOLO, ASSENTE_COPPIA, IGNOTA, ERRORE
    azione_presenze = models.TextField(blank=True, default='', help_text="Dettaglio allievo o coppia impostato come presente o assente")
    partner_coinvolto = models.ForeignKey(Allievo, on_delete=models.SET_NULL, null=True, blank=True, related_name='gemini_logs_partner', help_text="Partner coinvolto se presente in coppia")

    class Meta:
        verbose_name = "Log Gemini"
        verbose_name_plural = "Log Gemini"
        ordering = ['-timestamp']

    def __str__(self):
        soggetto = self.allievo if self.allievo else (self.mittente or "Sconosciuto")
        corso_str = f" [{self.corso}]" if self.corso else ""
        return f"[{self.timestamp.strftime('%d/%m/%Y %H:%M')}]{corso_str} {soggetto} -> {self.esito_interpretato}"


class DocumentTemplate(models.Model):
    CHIAVI = [
        ('ricevuta', 'Template Ricevuta Pagamento'),
        ('modulo_tesseramento', 'Modulo di Tesseramento'),
        ('verbale_rendiconto', 'Verbale Approvazione Rendiconto'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    chiave = models.CharField(max_length=50, unique=True, choices=CHIAVI)
    nome = models.CharField(max_length=100)
    descrizione = models.TextField(blank=True, default='')
    file = models.FileField(upload_to='templates_pdf/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Template Documento"
        verbose_name_plural = "Template Documenti"
        ordering = ['chiave']

    def __str__(self):
        return f"{self.nome} ({self.chiave})"

    @property
    def filename(self):
        if self.file and self.file.name:
            import os
            return os.path.basename(self.file.name)
        return ''

    @property
    def file_size(self):
        if self.file:
            try:
                return self.file.size
            except Exception:
                return 0
        return 0


# ─── 1.12 Ricevute ──────────────────────────────────────────────

class ContatoreRicevute(models.Model):
    anno = models.PositiveIntegerField(unique=True, help_text="Anno di riferimento (es. 2026)")
    ultimo_numero = models.PositiveIntegerField(default=0, help_text="Ultimo numero di ricevuta emesso per l'anno")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Contatore Ricevute"
        verbose_name_plural = "Contatori Ricevute"
        ordering = ['-anno']

    def __str__(self):
        return f"Anno {self.anno}: Ultimo N. {self.ultimo_numero}"


class Ricevuta(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    numero = models.PositiveIntegerField(help_text="Numero progressivo di ricevuta")
    anno = models.PositiveIntegerField(help_text="Anno di emissione (es. 2026)")
    data = models.DateField(default=timezone.now, help_text="Data di emissione della ricevuta")
    intestatario = models.CharField(max_length=255, help_text="Nome e cognome o ragione sociale dell'intestatario")
    causale = models.CharField(max_length=255, help_text="Causale del pagamento")
    importo = models.DecimalField(max_digits=10, decimal_places=2, help_text="Importo in Euro")
    note = models.TextField(blank=True, default='', help_text="Note aggiuntive (es. bonifico, contanti)")
    allievo = models.ForeignKey(Allievo, on_delete=models.SET_NULL, null=True, blank=True, related_name='ricevute')
    pagamento = models.ForeignKey('Pagamento', on_delete=models.SET_NULL, null=True, blank=True, related_name='ricevute', help_text="Pagamento a cui si riferisce la ricevuta")
    movimento_cassa = models.ForeignKey(
        'MovimentoPrimaNota',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ricevute',
        help_text="Movimento di prima nota cassa associato alla ricevuta"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Ricevuta"
        verbose_name_plural = "Ricevute"
        ordering = ['-anno', '-numero']
        unique_together = ('anno', 'numero')

    @property
    def numero_display(self):
        return f"N. {self.numero}/{self.anno}"

    @property
    def in_bilancio(self):
        return self.movimento_cassa_id is not None

    def __str__(self):
        return f"Ricevuta {self.numero_display} - {self.intestatario} (€ {self.importo})"


# ─── 1.13 Google Drive Configuration ───────────────────────────

class GoogleDriveConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    auth_type = models.CharField(
        max_length=20,
        default='oauth',
        choices=[
            ('oauth', 'OAuth 2.0 (Account Google Personale / Google Workspace)'),
            ('service_account', 'Service Account (Chiave Privata JSON)')
        ],
        help_text="Metodo di autenticazione Google Drive"
    )

    # Campi OAuth 2.0
    oauth_client_id = models.CharField(max_length=255, blank=True, default='', help_text="OAuth 2.0 Client ID")
    oauth_client_secret = models.CharField(max_length=255, blank=True, default='', help_text="OAuth 2.0 Client Secret")
    oauth_access_token = models.TextField(blank=True, default='', help_text="OAuth 2.0 Access Token")
    oauth_refresh_token = models.TextField(blank=True, default='', help_text="OAuth 2.0 Refresh Token")
    oauth_token_expiry = models.DateTimeField(null=True, blank=True, help_text="Scadenza Access Token")
    oauth_user_email = models.CharField(max_length=255, blank=True, default='', help_text="Email account Google autenticato via OAuth")
    oauth_user_name = models.CharField(max_length=255, blank=True, default='', help_text="Nome account Google")

    # Campi Service Account (Legacy/Workspace)
    credentials_file = models.FileField(upload_to='google_drive/', null=True, blank=True, help_text="File JSON chiave privata / Service Account di Google Drive")
    client_email = models.CharField(max_length=255, blank=True, default='', help_text="Email dell'account di servizio (da abilitare sulle cartelle Drive)")
    project_id = models.CharField(max_length=255, blank=True, default='', help_text="ID Progetto Google Cloud")
    private_key_id = models.CharField(max_length=255, blank=True, default='', help_text="ID chiave privata")

    # Cartelle di destinazione
    folder_id = models.CharField(max_length=255, blank=True, default='', help_text="ID cartella predefinita Google Drive")
    folder_ricevute_id = models.CharField(max_length=255, blank=True, default='', help_text="ID cartella Google Drive per Ricevute")
    folder_ricevute_nome = models.CharField(max_length=255, blank=True, default='', help_text="Nome cartella Google Drive per Ricevute")
    folder_tessere_id = models.CharField(max_length=255, blank=True, default='', help_text="ID cartella Google Drive per Tessere")
    folder_tessere_nome = models.CharField(max_length=255, blank=True, default='', help_text="Nome cartella Google Drive per Tessere")
    folder_verbali_id = models.CharField(max_length=255, blank=True, default='', help_text="ID cartella Google Drive per Verbali")
    folder_verbali_nome = models.CharField(max_length=255, blank=True, default='', help_text="Nome cartella Google Drive per Verbali")
    is_active = models.BooleanField(default=True, help_text="Stato attivazione integrazione Google Drive")
    last_tested_at = models.DateTimeField(null=True, blank=True)
    last_test_status = models.CharField(max_length=50, blank=True, default='')  # 'success', 'error'
    last_test_message = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Configurazione Google Drive"
        verbose_name_plural = "Configurazioni Google Drive"

    def __str__(self):
        status = "Configurato" if self.is_configured else "Non configurato"
        user_display = self.oauth_user_email if self.auth_type == 'oauth' else self.client_email
        return f"Google Drive ({status} - {self.auth_type} - {user_display or 'Nessun account'})"

    @classmethod
    def get_instance(cls):
        inst = cls.objects.first()
        if not inst:
            inst = cls.objects.create()
        return inst

    @property
    def is_sa_configured(self):
        import os
        return bool(self.credentials_file and self.credentials_file.name and os.path.exists(self.credentials_file.path))

    @property
    def is_oauth_connected(self):
        return bool(self.oauth_refresh_token)

    @property
    def is_configured(self):
        if self.auth_type == 'service_account':
            return self.is_sa_configured
        return self.is_oauth_connected

    @property
    def filename(self):
        if self.credentials_file and self.credentials_file.name:
            import os
            return os.path.basename(self.credentials_file.name)
        return ''

    @property
    def file_size(self):
        if self.credentials_file:
            try:
                return self.credentials_file.size
            except Exception:
                return 0
        return 0


# ─── 1.13b Google Contacts Configuration ────────────────────────

class GoogleContactsConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # Credenziali OAuth 2.0
    client_id = models.CharField(max_length=255, blank=True, default='', help_text="OAuth 2.0 Client ID per Google Contacts")
    client_secret = models.CharField(max_length=255, blank=True, default='', help_text="OAuth 2.0 Client Secret per Google Contacts")
    
    # Token di accesso OAuth 2.0
    access_token = models.TextField(blank=True, default='', help_text="OAuth 2.0 Access Token")
    refresh_token = models.TextField(blank=True, default='', help_text="OAuth 2.0 Refresh Token")
    token_expiry = models.DateTimeField(null=True, blank=True, help_text="Scadenza Access Token")
    user_email = models.CharField(max_length=255, blank=True, default='', help_text="Email account Google autenticato via OAuth")
    user_name = models.CharField(max_length=255, blank=True, default='', help_text="Nome account Google")
    
    # Opzioni di sincronizzazione
    sync_group_name = models.CharField(max_length=100, blank=True, default='Allievi Tango', help_text="Nome gruppo/etichetta contatti in Google Contacts")
    is_active = models.BooleanField(default=True, help_text="Stato attivazione integrazione Google Contacts")
    last_sync_at = models.DateTimeField(null=True, blank=True, help_text="Data e ora ultima sincronizzazione")
    last_sync_status = models.CharField(max_length=50, blank=True, default='')  # 'success', 'error', 'in_progress'
    last_sync_summary = models.TextField(blank=True, default='', help_text="Riepilogo esito ultima sincronizzazione")
    last_test_status = models.CharField(max_length=50, blank=True, default='')  # 'success', 'error'
    last_test_message = models.TextField(blank=True, default='')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Configurazione Google Contacts"
        verbose_name_plural = "Configurazioni Google Contacts"

    def __str__(self):
        status = "Collegato" if self.is_connected else "Non collegato"
        return f"Google Contacts ({status} - {self.user_email or 'Nessun account'})"

    @classmethod
    def get_instance(cls):
        inst = cls.objects.first()
        if not inst:
            inst = cls.objects.create()
        return inst

    @property
    def is_connected(self):
        return bool(self.refresh_token)

    @property
    def has_client_secret(self):
        return bool(self.client_secret)


# ─── 1.14 Bilancio: Prima Nota Cassa ────────────────────────────

class MovimentoPrimaNota(models.Model):
    TIPO_CHOICES = [
        ('entrata', 'Entrata'),
        ('uscita', 'Uscita'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    data = models.DateField(default=timezone.now, help_text="Data del movimento")
    descrizione = models.CharField(max_length=255, help_text="Descrizione del movimento")
    categoria = models.CharField(max_length=100, default='Generale', help_text="Categoria del movimento")
    tipo = models.CharField(max_length=10, choices=TIPO_CHOICES, default='entrata', help_text="Entrata o Uscita")
    importo = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Importo del movimento in Euro")
    note = models.TextField(blank=True, default='', help_text="Note aggiuntive")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Movimento Prima Nota"
        verbose_name_plural = "Prima Nota Cassa"
        ordering = ['-data', '-created_at']

    def __str__(self):
        segno = '+' if self.tipo == 'entrata' else '-'
        return f"[{self.data.strftime('%d/%m/%Y')}] {self.descrizione} ({self.categoria}): {segno}€{self.importo}"


class CategoriaBilancio(models.Model):
    TIPO_CHOICES = [
        ('entrata', 'Entrata'),
        ('uscita', 'Uscita'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nome = models.CharField(max_length=100, help_text="Nome della categoria")
    tipo = models.CharField(max_length=10, choices=TIPO_CHOICES, default='entrata', help_text="Tipo: Entrata o Uscita")
    descrizione = models.CharField(max_length=255, blank=True, default='', help_text="Descrizione opzionale")
    colore = models.CharField(max_length=20, blank=True, default='', help_text="Colore hex opzionale")
    ordine = models.IntegerField(default=0, help_text="Ordinamento nella lista")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Categoria Bilancio"
        verbose_name_plural = "Categorie Bilancio"
        unique_together = ('nome', 'tipo')
        ordering = ['tipo', 'ordine', 'nome']

    def __str__(self):
        return f"[{self.get_tipo_display()}] {self.nome}"

    @classmethod
    def ensure_defaults(cls):
        """Inizializza le categorie predefinite se la tabella è vuota."""
        if cls.objects.exists():
            return

        defaults_entrate = [
            ("Quote corsi", "Quote mensili e trimestrali dei corsi ordinari", 1),
            ("Tesseramenti", "Quote di tesseramento annuale", 2),
            ("Milonghe / Serate", "Ingressi a milonghe, pratiche e serate danzanti", 3),
            ("Stage / Workshop", "Quote per stage speciali e lezioni con maestri ospiti", 4),
            ("Lezioni private", "Corrispettivi per lezioni individuali o di coppia", 5),
            ("Quote associative", "Quote di adesione all'associazione", 6),
            ("Donazioni / Contributi", "Donazioni liberali e contributi volontari", 7),
            ("Varie entrate", "Altre entrate e incassi diversi", 8),
        ]

        defaults_uscite = [
            ("Affitto sale", "Canoni di locazione e noleggio sale da ballo", 1),
            ("Compensi maestri", "Compensi e rimborsi per insegnanti e assistenti", 2),
            ("SIAE / SCF", "Diritti musicali d'autore e diritti connessi", 3),
            ("Attrezzatura / Service", "Impianti audio, luci, microfoni e materiale", 4),
            ("Grafica / Pubblicità / Web", "Volantini, campagne social, sito web e domini", 5),
            ("Rinfreschi / Bar", "Acquisto bevande e cibo per pratiche e serate", 6),
            ("Spese bancarie / Gestionali", "Commissioni POS, conto corrente e software", 7),
            ("Assicurazioni", "Polizze RCT e infortuni per allievi e associazione", 8),
            ("Varie uscite", "Altre spese operative e imprevisti", 9),
        ]

        for nome, desc, ord_idx in defaults_entrate:
            cls.objects.get_or_create(
                nome=nome,
                tipo='entrata',
                defaults={'descrizione': desc, 'ordine': ord_idx}
            )

        for nome, desc, ord_idx in defaults_uscite:
            cls.objects.get_or_create(
                nome=nome,
                tipo='uscita',
                defaults={'descrizione': desc, 'ordine': ord_idx}
            )


# ─── 1.15 Dati ASD e Direttivo ─────────────────────────────────

class ConfigurazioneASD(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nome = models.CharField(max_length=255, default='TantoTango ASD', help_text="Denominazione dell'Associazione")
    codice_fiscale = models.CharField(max_length=50, blank=True, default='', help_text="Codice Fiscale dell'ASD")
    partita_iva = models.CharField(max_length=50, blank=True, default='', help_text="Partita IVA (se presente)")
    sede_legale = models.CharField(max_length=255, blank=True, default='', help_text="Indirizzo della sede legale")
    sede_operativa = models.CharField(max_length=255, blank=True, default='', help_text="Indirizzo della sede operativa")
    telefono = models.CharField(max_length=50, blank=True, default='', help_text="Recapito telefonico ASD")
    email = models.EmailField(blank=True, default='', help_text="Email di contatto ASD")
    pec = models.EmailField(blank=True, default='', help_text="Indirizzo Posta Elettronica Certificata (PEC)")
    sito_web = models.CharField(max_length=255, blank=True, default='', help_text="Sito web istituzionale")
    codice_affiliazione = models.CharField(max_length=100, blank=True, default='', help_text="Codice affiliazione EPS / CONI / Registro Nazionale")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Dati ASD"
        verbose_name_plural = "Dati ASD"

    def __str__(self):
        return f"{self.nome} (CF: {self.codice_fiscale or 'N/D'})"

    @classmethod
    def get_instance(cls):
        inst = cls.objects.first()
        if not inst:
            inst = cls.objects.create(nome='TantoTango ASD')
        return inst


class MembroDirettivo(models.Model):
    RUOLI = [
        ('presidente', 'Presidente'),
        ('vicepresidente', 'Vicepresidente'),
        ('segretario', 'Segretario'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ruolo = models.CharField(max_length=50, choices=RUOLI, unique=True, help_text="Ruolo all'interno del Direttivo")
    nome = models.CharField(max_length=100, blank=True, default='', help_text="Nome")
    cognome = models.CharField(max_length=100, blank=True, default='', help_text="Cognome")
    codice_fiscale = models.CharField(max_length=16, blank=True, default='', help_text="Codice Fiscale personale")
    data_nascita = models.DateField(null=True, blank=True, help_text="Data di nascita")
    luogo_nascita = models.CharField(max_length=100, blank=True, default='', help_text="Luogo di nascita")
    telefono = models.CharField(max_length=50, blank=True, default='', help_text="Telefono")
    email = models.EmailField(blank=True, default='', help_text="Email")
    firma = models.ImageField(upload_to='firme_direttivo/', null=True, blank=True, help_text="Immagine della firma")
    ordine = models.PositiveIntegerField(default=1, help_text="Ordinamento nella visualizzazione")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Membro del Direttivo"
        verbose_name_plural = "Direttivo ASD"
        ordering = ['ordine', 'ruolo']

    def __str__(self):
        nome_completo = f"{self.nome} {self.cognome}".strip()
        return f"{self.get_ruolo_display()}: {nome_completo or 'Non assegnato'}"

    @property
    def nome_completo(self):
        val = f"{self.nome} {self.cognome}".strip()
        return val if val else f"[{self.get_ruolo_display()}]"

    @property
    def has_firma(self):
        return bool(self.firma and self.firma.name)

    @property
    def firma_url(self):
        if self.has_firma:
            return f"/api/direttivo/{self.id}/firma-file/"
        return None

    @classmethod
    def ensure_defaults(cls):
        """Assicura l'esistenza delle 3 cariche obbligatorie: Presidente, Vicepresidente, Segretario."""
        defaults = [
            ('presidente', 1),
            ('vicepresidente', 2),
            ('segretario', 3),
        ]
        for r, ord_idx in defaults:
            cls.objects.get_or_create(
                ruolo=r,
                defaults={'ordine': ord_idx}
            )






class GoogleContactsSyncLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    timestamp = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=50, default='success')  # 'success', 'error', 'partial'
    action = models.CharField(max_length=100, default='bulk_sync')  # 'bulk_sync', 'push_to_google', 'pull_from_google', 'delete_google', 'import_allievo'
    details = models.TextField(blank=True, default='')
    items_created = models.IntegerField(default=0)
    items_updated = models.IntegerField(default=0)
    items_deleted = models.IntegerField(default=0)
    errors_count = models.IntegerField(default=0)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = "Log Sincronizzazione Google Contacts"
        verbose_name_plural = "Log Sincronizzazioni Google Contacts"

    def __str__(self):
        return f"SyncLog {self.action} ({self.status}) - {self.timestamp.strftime('%d/%m/%Y %H:%M')}"
