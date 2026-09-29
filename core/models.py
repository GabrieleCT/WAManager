import uuid
from django.db import models


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

    def __str__(self):
        return f"{self.scuola.nome} - {self.get_livello_display()} ({self.orario.strftime('%H:%M')}) [{self.anno_accademico}]"


# ─── 1.5 Argomento ──────────────────────────────────────────────

class Argomento(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    titolo = models.CharField(max_length=200)
    descrizione = models.TextField(blank=True, default='')
    livello = models.CharField(max_length=20, choices=Level.choices, default=Level.PRINCIPIANTE)

    class Meta:
        verbose_name_plural = 'Argomenti'
        ordering = ['titolo']

    def __str__(self):
        return f"{self.titolo} ({self.get_livello_display()})"


# ─── 1.1 Allievo (include Prospect con flag is_prospect) ─────────

class Allievo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nome = models.CharField(max_length=100)
    cognome = models.CharField(max_length=100)
    ruolo = models.CharField(max_length=10, choices=Role.choices, default=Role.LEADER)
    telefono = models.CharField(max_length=20)
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

    class Meta:
        verbose_name_plural = 'Allievi'
        ordering = ['cognome', 'nome']

    def __str__(self):
        prefix = "[Prospect] " if self.is_prospect else ""
        return f"{prefix}{self.nome} {self.cognome}"


# ─── 1.4 Jolly ──────────────────────────────────────────────────

class Jolly(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    allievo = models.ForeignKey(Allievo, on_delete=models.CASCADE, related_name='jolly_entries')
    priorita = models.PositiveIntegerField(default=1, help_text="1 = priorità più alta")

    class Meta:
        verbose_name_plural = 'Jolly'
        ordering = ['priorita']

    def __str__(self):
        return f"Jolly: {self.allievo} (priorità {self.priorita})"


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
    presente = models.BooleanField(default=False)
    fonte = models.CharField(max_length=20, choices=FONTE_CHOICES, default='manuale')
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
    note = models.TextField(blank=True, default='')

    class Meta:
        verbose_name_plural = 'Pagamenti'
        ordering = ['-data_pagamento']

    def __str__(self):
        return f"{self.allievo} - {self.corso} - {self.get_trimestre_display()} - €{self.importo}"


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

    def __str__(self):
        corso_str = str(self.corso) if self.corso else "Globale"
        return f"{corso_str} - Giorni {self.days_of_week} alle {self.time}"

class SondaggioMattutinoConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    corso = models.ForeignKey(Corso, on_delete=models.CASCADE, related_name='sondaggi')
    testo = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Sondaggio {self.corso} - {self.is_active}'
