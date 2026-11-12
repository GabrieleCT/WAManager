from datetime import date, time
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Allievo, Corso, Scuola


class ProspectModuloTesseramentoTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="tester", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.scuola = Scuola.objects.create(nome="Scuola Test", sede="Via Roma 1")
        self.corso = Corso.objects.create(
            scuola=self.scuola,
            livello="principiante",
            giorno_settimana="MARTEDI",
            orario=time(20, 30),
        )
        self.prospect_senza_corso = Allievo.objects.create(
            nome="Mario",
            cognome="Rossi",
            telefono="393401112233",
            is_prospect=True,
        )
        self.prospect_con_corso = Allievo.objects.create(
            nome="Giulia",
            cognome="Bianchi",
            telefono="TBD",
            corso=self.corso,
            is_prospect=True,
        )

    def test_prospect_modulo_tesseramento_pdf_without_corso(self):
        res = self.client.get(f"/api/allievi/{self.prospect_senza_corso.id}/modulo-tesseramento-pdf/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Type"], "application/pdf")
        content = b"".join(res.streaming_content)
        self.assertTrue(content.startswith(b"%PDF"))

    def test_prospect_modulo_tesseramento_pdf_with_corso(self):
        res = self.client.get(f"/api/allievi/{self.prospect_con_corso.id}/modulo-tesseramento-pdf/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Content-Type"], "application/pdf")
        content = b"".join(res.streaming_content)
        self.assertTrue(content.startswith(b"%PDF"))

    @patch("core.wa_client.send_whatsapp_document")
    def test_send_modulo_tesseramento_to_prospect(self, mock_send_doc):
        mock_send_doc.return_value = {"success": True}
        res = self.client.post(
            f"/api/allievi/{self.prospect_senza_corso.id}/send-modulo-tesseramento/",
            {"messaggio": "Ciao Mario, ecco il modulo."},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["success"])
        mock_send_doc.assert_called_once()
        kwargs = mock_send_doc.call_args.kwargs
        self.assertEqual(kwargs["to"], "393401112233")
        self.assertEqual(kwargs["filename"], "Modulo_Tesseramento_Rossi_Mario.pdf")
        self.assertEqual(kwargs["caption"], "Ciao Mario, ecco il modulo.")

    def test_send_modulo_tesseramento_to_prospect_without_valid_phone_returns_400(self):
        res = self.client.post(
            f"/api/allievi/{self.prospect_con_corso.id}/send-modulo-tesseramento/",
            {},
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        body = res.json()
        self.assertFalse(body["success"])
        self.assertIn("Il prospect Giulia Bianchi", body["error"])


class AllievoDataAmmissioneTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_test", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_create_and_update_allievo_with_data_ammissione(self):
        res = self.client.post(
            "/api/allievi/",
            {
                "nome": "Elena",
                "cognome": "Neri",
                "ruolo": "follower",
                "livello": "principiante",
                "tessera_associativa": "42",
                "data_ammissione": "2025-10-15",
                "tesserato_altra_asd": True,
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["data_ammissione"], "2025-10-15")
        self.assertNotIn("data_emissione_tessera", data)
        self.assertEqual(data["stato_tessera"], "TESSERATO ESTERNO")

        allievo = Allievo.objects.get(id=data["id"])
        self.assertEqual(allievo.data_ammissione, date(2025, 10, 15))

        res_patch = self.client.patch(
            f"/api/allievi/{allievo.id}/",
            {"data_ammissione": ""},
            format="json",
        )
        self.assertEqual(res_patch.status_code, 200)
        self.assertIsNone(res_patch.json()["data_ammissione"])

    def test_stato_tessera_filters_without_data_emissione(self):
        Allievo.objects.create(
            nome="Marco",
            cognome="Blu",
            tessera_associativa="10",
            data_ammissione=date(2024, 1, 10),
        )
        res_ok = self.client.get("/api/allievi/?stato_tessera=ok")
        self.assertEqual(res_ok.status_code, 200)
        self.assertEqual(len(res_ok.json()), 1)

        res_scaduta = self.client.get("/api/allievi/?stato_tessera=scaduta")
        self.assertEqual(res_scaduta.status_code, 200)
        self.assertEqual(res_scaduta.json(), [])


class AllievoCertificatoMedicoTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_cert", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_create_update_and_clear_scadenza_certificato_medico(self):
        res = self.client.post(
            "/api/allievi/",
            {
                "nome": "Luca",
                "cognome": "Gialli",
                "ruolo": "leader",
                "livello": "intermedio",
                "scadenza_certificato_medico": "2027-05-20",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["scadenza_certificato_medico"], "2027-05-20")

        allievo = Allievo.objects.get(id=data["id"])
        self.assertEqual(allievo.scadenza_certificato_medico, date(2027, 5, 20))

        res_patch = self.client.patch(
            f"/api/allievi/{allievo.id}/",
            {"scadenza_certificato_medico": ""},
            format="json",
        )
        self.assertEqual(res_patch.status_code, 200)
        self.assertIsNone(res_patch.json()["scadenza_certificato_medico"])

    def test_filter_certificato_medico_senza_valido_scaduto(self):
        from datetime import timedelta
        from django.utils import timezone

        today = timezone.localdate()
        senza = Allievo.objects.create(nome="Senza", cognome="Uno")
        valido = Allievo.objects.create(
            nome="Valido",
            cognome="Due",
            scadenza_certificato_medico=today + timedelta(days=30),
        )
        scaduto = Allievo.objects.create(
            nome="Scaduto",
            cognome="Tre",
            scadenza_certificato_medico=today - timedelta(days=5),
        )

        res_senza = self.client.get("/api/allievi/?certificato_medico=senza")
        self.assertEqual(res_senza.status_code, 200)
        self.assertEqual([r["id"] for r in res_senza.json()], [str(senza.id)])

        res_valido = self.client.get("/api/allievi/?certificato_medico=valido")
        self.assertEqual(res_valido.status_code, 200)
        self.assertEqual([r["id"] for r in res_valido.json()], [str(valido.id)])

        res_scaduto = self.client.get("/api/allievi/?certificato_medico=scaduto")
        self.assertEqual(res_scaduto.status_code, 200)
        self.assertEqual([r["id"] for r in res_scaduto.json()], [str(scaduto.id)])

        res_presente = self.client.get("/api/allievi/?certificato_medico=presente")
        self.assertEqual(res_presente.status_code, 200)
        self.assertEqual(
            {r["id"] for r in res_presente.json()},
            {str(valido.id), str(scaduto.id)},
        )


class AggiungiJollyLezioneTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_jolly", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    @patch("core.api_views.send_whatsapp_message", return_value={"success": True})
    def test_aggiungi_jolly_sets_pending_status_and_sends_whatsapp(self, mock_send):
        from core.models import Scuola, Corso, Lezione, Presenza
        from datetime import time

        scuola = Scuola.objects.create(nome="Sede Centro")
        corso = Corso.objects.create(
            scuola=scuola,
            livello="principiante",
            giorno_settimana="lunedi",
            orario=time(20, 30),
        )
        lezione = Lezione.objects.create(
            corso=corso,
            data=date(2026, 11, 12),
            titolo="Lezione 1",
        )
        allievo = Allievo.objects.create(
            nome="Chiara",
            cognome="Bianchi",
            nickname="Chiary",
            ruolo="follower",
            telefono="+393331234567",
        )

        res = self.client.post(
            f"/api/lezioni/{lezione.id}/aggiungi-jolly/",
            {
                "allievo_id": str(allievo.id),
                "invia_whatsapp": True,
                "testo": "Ciao {nickname}, riesci a venire come Jolly stasera?",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertIsNone(data["presente"])
        self.assertTrue(data["is_jolly"])
        self.assertTrue(data["whatsapp"]["success"])
        self.assertEqual(
            data["whatsapp"]["messaggio"],
            "Ciao Chiary, riesci a venire come Jolly stasera?",
        )

        presenza = Presenza.objects.get(lezione=lezione, allievo=allievo)
        self.assertIsNone(presenza.presente)
        self.assertTrue(presenza.is_jolly)
        mock_send.assert_called_once_with(
            to="+393331234567",
            message="Ciao Chiary, riesci a venire come Jolly stasera?",
            is_group=False,
        )
