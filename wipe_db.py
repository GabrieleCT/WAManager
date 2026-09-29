from core.models import *; [m.objects.all().delete() for m in [Allievo, Lezione, Corso, Scuola, Pagamento, Presenza, Prospect, Argomento, Jolly]]
