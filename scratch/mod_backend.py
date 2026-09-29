
import os

models_path = r'C:\Users\gabriele.cataldo\OneDrive - Banca Mediolanum SPA\Desktop\private\tango\gestionale\WAManager\core\models.py'
with open(models_path, 'a', encoding='utf-8') as f:
    f.write('''
class SondaggioMattutinoConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    corso = models.ForeignKey(Corso, on_delete=models.CASCADE, related_name='sondaggi')
    testo = models.TextField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Sondaggio {self.corso} - {self.is_active}'
''')
print('Added model SondaggioMattutinoConfig')

