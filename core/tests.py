from datetime import date, time
from decimal import Decimal
from unittest.mock import patch, MagicMock
from django.contrib.auth import get_user_model
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Allievo, Corso, Scuola, Socio, CategoriaSocio, OrigineSocio, MotivoCessazione
from .serializers import AllievoSerializer


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


class AllievoResidenzaTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_residenza", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_create_and_update_allievo_with_residenza(self):
        res = self.client.post(
            "/api/allievi/",
            {
                "nome": "Marco",
                "cognome": "Rossi",
                "ruolo": "leader",
                "livello": "principiante",
                "indirizzo_residenza": "Via Roma, 10",
                "comune_residenza": "MILANO",
                "provincia_residenza": "MI",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["indirizzo_residenza"], "Via Roma, 10")
        self.assertEqual(data["comune_residenza"], "MILANO")
        self.assertEqual(data["provincia_residenza"], "MI")

        allievo = Allievo.objects.get(id=data["id"])
        self.assertEqual(allievo.indirizzo_residenza, "Via Roma, 10")
        self.assertEqual(allievo.comune_residenza, "MILANO")
        self.assertEqual(allievo.provincia_residenza, "MI")

        # Test search by comune_residenza
        search_res = self.client.get("/api/allievi/?search=MILANO")
        self.assertEqual(search_res.status_code, 200)
        self.assertIn(str(allievo.id), [r["id"] for r in search_res.json()])

        # Test patch update
        res_patch = self.client.patch(
            f"/api/allievi/{allievo.id}/",
            {
                "indirizzo_residenza": "Corso Buenos Aires, 45",
                "comune_residenza": "SEGRATE",
                "provincia_residenza": "MI",
            },
            format="json",
        )
        self.assertEqual(res_patch.status_code, 200)
        patch_data = res_patch.json()
        self.assertEqual(patch_data["indirizzo_residenza"], "Corso Buenos Aires, 45")
        self.assertEqual(patch_data["comune_residenza"], "SEGRATE")


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
                "testo": "Ciao {nickname}, riesci a venire come Jolly stasera per le {orario}?",
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
            "Ciao Chiary, riesci a venire come Jolly stasera per le 20:30?",
        )

        presenza = Presenza.objects.get(lezione=lezione, allievo=allievo)
        self.assertIsNone(presenza.presente)
        self.assertTrue(presenza.is_jolly)
        mock_send.assert_called_once_with(
            to="+393331234567",
            message="Ciao Chiary, riesci a venire come Jolly stasera per le 20:30?",
            is_group=False,
        )

    @patch("core.api_views.send_whatsapp_message", return_value={"success": True})
    def test_aggiungi_jolly_multipli_con_placeholder_orario_e_nickname(self, mock_send):
        from core.models import Scuola, Corso, Lezione, Presenza
        from datetime import time

        scuola = Scuola.objects.create(nome="Sede Sud")
        corso = Corso.objects.create(
            scuola=scuola,
            livello="intermedio",
            giorno_settimana="mercoledi",
            orario=time(19, 30),
        )
        lezione = Lezione.objects.create(corso=corso, data=date(2026, 11, 14))
        a1 = Allievo.objects.create(nome="Rocco", cognome="Siffredi", nickname="Rocco", ruolo="leader", telefono="+393331111111")
        a2 = Allievo.objects.create(nome="Maria", cognome="Rossi", nickname="Mary", ruolo="follower", telefono="+393332222222")

        res = self.client.post(
            f"/api/lezioni/{lezione.id}/aggiungi-jolly/",
            {
                "allievo_ids": [str(a1.id), str(a2.id)],
                "invia_whatsapp": True,
                "testo": "Ciao {nickname}! Saresti disponibile come Jolly stasera alle {orario}?",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["count"], 2)

        self.assertEqual(mock_send.call_count, 2)
        mock_send.assert_any_call(
            to="+393331111111",
            message="Ciao Rocco! Saresti disponibile come Jolly stasera alle 19:30?",
            is_group=False,
        )
        mock_send.assert_any_call(
            to="+393332222222",
            message="Ciao Mary! Saresti disponibile come Jolly stasera alle 19:30?",
            is_group=False,
        )

    @patch("core.api_views.send_whatsapp_message", return_value={"success": True})
    def test_aggiungi_jolly_multipli_quando_testo_ha_nome_primo_allievo_sostituisce_per_altri(self, mock_send):
        from core.models import Scuola, Corso, Lezione, Presenza
        from datetime import time

        scuola = Scuola.objects.create(nome="Sede Sud")
        corso = Corso.objects.create(
            scuola=scuola,
            livello="intermedio",
            giorno_settimana="mercoledi",
            orario=time(20, 30),
        )
        lezione = Lezione.objects.create(corso=corso, data=date(2026, 11, 14))
        a1 = Allievo.objects.create(nome="Rocco", cognome="Verdi", nickname="Rocco", ruolo="leader", telefono="+393331111111")
        a2 = Allievo.objects.create(nome="Maria", cognome="Rossi", nickname="Mary", ruolo="follower", telefono="+393332222222")

        # Il client ha erroneamente inviato il testo contenente "Rocco" per l'invio multiplo
        res = self.client.post(
            f"/api/lezioni/{lezione.id}/aggiungi-jolly/",
            {
                "allievo_ids": [str(a1.id), str(a2.id)],
                "invia_whatsapp": True,
                "testo": "Ciao Rocco! Saresti disponibile come Jolly stasera dalle {orario}?",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(mock_send.call_count, 2)
        mock_send.assert_any_call(
            to="+393331111111",
            message="Ciao Rocco! Saresti disponibile come Jolly stasera dalle 20:30?",
            is_group=False,
        )
        # Maria NON deve ricevere "Ciao Rocco", ma "Ciao Mary"
        mock_send.assert_any_call(
            to="+393332222222",
            message="Ciao Mary! Saresti disponibile come Jolly stasera dalle 20:30?",
            is_group=False,
        )

    @patch("core.api_views.send_whatsapp_message")
    def test_aggiungi_jolly_multipli_senza_whatsapp(self, mock_send):
        from core.models import Scuola, Corso, Lezione, Presenza
        from datetime import time

        scuola = Scuola.objects.create(nome="Sede Est")
        corso = Corso.objects.create(
            scuola=scuola,
            livello="intermedio",
            giorno_settimana="martedi",
            orario=time(21, 00),
        )
        lezione = Lezione.objects.create(corso=corso, data=date(2026, 11, 13))
        a1 = Allievo.objects.create(nome="Paolo", cognome="Verdi", ruolo="leader", telefono="+393331111111")
        a2 = Allievo.objects.create(nome="Anna", cognome="Neri", ruolo="follower", telefono="+393332222222")

        res = self.client.post(
            f"/api/lezioni/{lezione.id}/aggiungi-jolly/",
            {
                "allievo_ids": [str(a1.id), str(a2.id)],
                "invia_whatsapp": False,
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["count"], 2)
        self.assertFalse(data["invia_whatsapp"])
        mock_send.assert_not_called()

        p1 = Presenza.objects.get(lezione=lezione, allievo=a1)
        self.assertIsNone(p1.presente)
        self.assertTrue(p1.is_jolly)

        p2 = Presenza.objects.get(lezione=lezione, allievo=a2)
        self.assertIsNone(p2.presente)
        self.assertTrue(p2.is_jolly)


class GoogleDriveCertificatiFolderTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_drive", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_update_and_get_folder_certificati(self):
        from core.models import GoogleDriveConfig

        res = self.client.post(
            "/api/google-drive/update-settings/",
            {
                "folder_certificati_id": "folder_cert_123",
                "folder_certificati_nome": "Certificati Medici 2026",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["config"]["folder_certificati_id"], "folder_cert_123")
        self.assertEqual(data["config"]["folder_certificati_nome"], "Certificati Medici 2026")

        config = GoogleDriveConfig.get_instance()
        self.assertEqual(config.folder_certificati_id, "folder_cert_123")
        self.assertEqual(config.folder_certificati_nome, "Certificati Medici 2026")

        res_get = self.client.get("/api/google-drive/")
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json()["folder_certificati_id"], "folder_cert_123")
        self.assertEqual(res_get.json()["folder_certificati_nome"], "Certificati Medici 2026")


class ImportDocumentiDriveTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="admin_import", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        self.scuola = Scuola.objects.create(nome="Scuola Tango")
        self.corso = Corso.objects.create(
            scuola=self.scuola,
            livello="Principiante",
            orario="20:00",
            anno_accademico="2025/2026"
        )
        self.allievo = Allievo.objects.create(
            nome="Mario",
            cognome="Rossi",
            telefono="393331122334",
            corso=self.corso,
            ruolo="Leader"
        )

    @patch("core.wa_client.get_whatsapp_contact_media", return_value={"success": True, "files": [{"id": "doc1.jpg", "fileName": "doc1.jpg"}]})
    def test_get_whatsapp_media(self, mock_media):
        res = self.client.get(f"/api/allievi/{self.allievo.id}/whatsapp-media/")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(len(data["files"]), 1)
        self.assertEqual(data["files"][0]["fileName"], "doc1.jpg")

    @patch("core.api_views.get_google_drive_service")
    def test_import_documento_drive_converts_images_to_pdf(self, mock_get_service):
        from core.models import GoogleDriveConfig
        from PIL import Image
        import io
        from django.core.files.uploadedfile import SimpleUploadedFile

        config = GoogleDriveConfig.get_instance()
        config.folder_id = "default_folder_id"
        config.folder_certificati_id = "cert_folder_id"
        config.folder_certificati_nome = "Certificati"
        config.auth_type = "oauth"
        config.oauth_refresh_token = "valid_refresh_token"
        config.save()

        mock_drive_service = MagicMock()
        mock_files = MagicMock()
        mock_create = MagicMock()
        mock_create.execute.return_value = {
            "id": "drive_uploaded_file_id",
            "name": "Mario_Rossi.pdf",
            "webViewLink": "https://drive.google.com/file/d/drive_uploaded_file_id/view"
        }
        mock_files.create.return_value = mock_create
        mock_drive_service.files.return_value = mock_files
        mock_get_service.return_value = mock_drive_service

        img1 = Image.new("RGB", (100, 100), color="red")
        buf1 = io.BytesIO()
        img1.save(buf1, format="JPEG")
        file1 = SimpleUploadedFile("page1.jpg", buf1.getvalue(), content_type="image/jpeg")

        img2 = Image.new("RGB", (100, 100), color="blue")
        buf2 = io.BytesIO()
        img2.save(buf2, format="JPEG")
        file2 = SimpleUploadedFile("page2.jpg", buf2.getvalue(), content_type="image/jpeg")

        res = self.client.post(
            f"/api/allievi/{self.allievo.id}/import-documento-drive/",
            {
                "tipo_documento": "certificati",
                "convert_to_pdf": "true",
                "filename": "Mario_Rossi.pdf",
                "files": [file1, file2],
            },
            format="multipart"
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(len(data["uploaded_files"]), 1)
        self.assertEqual(data["uploaded_files"][0]["name"], "Mario_Rossi.pdf")
        self.assertEqual(data["folder_nome"], "Certificati")

    def test_prospect_creation_and_conversion_keeps_tessera_empty(self):
        # 1. Creazione prospect tramite serializer
        serializer = AllievoSerializer(data={
            "nome": "Prospect",
            "cognome": "Test",
            "is_prospect": True,
            "ruolo": "leader",
        })
        self.assertTrue(serializer.is_valid(), serializer.errors)
        prospect = serializer.save()
        self.assertEqual(prospect.tessera_associativa, "")
        self.assertEqual(prospect.numero_tessera_acsi, "")

        # 2. Conversione status tramite convert-status
        corso = Corso.objects.create(
            scuola=self.scuola,
            livello="principiante",
            orario="20:00:00",
            giorno_settimana="LUNEDI"
        )
        response = self.client.post(
            f"/api/allievi/{prospect.id}/convert-status/",
            {"corso_id": str(corso.id)},
            format="json"
        )
        self.assertEqual(response.status_code, 200)
        prospect.refresh_from_db()
        self.assertFalse(prospect.is_prospect)
        self.assertEqual(prospect.tessera_associativa, "")
        self.assertEqual(prospect.numero_tessera_acsi, "")

        # 3. Conversione status tramite convert_to_student
        prospect2 = Allievo.objects.create(
            nome="Prospect2",
            cognome="Test2",
            is_prospect=True,
            tessera_associativa="999",
            numero_tessera_acsi="888",
        )
        resp2 = self.client.post(
            f"/api/allievi/{prospect2.id}/convert_to_student/",
            {"corso_id": str(corso.id)},
            format="json"
        )
        self.assertEqual(resp2.status_code, 200)
        prospect2.refresh_from_db()
        self.assertFalse(prospect2.is_prospect)
        self.assertEqual(prospect2.tessera_associativa, "")
        self.assertEqual(prospect2.numero_tessera_acsi, "")

    def test_export_global_xlsx_handles_global_sondaggi_config(self):
        from rest_framework.authtoken.models import Token
        from .models import SondaggioMattutinoConfig
        token, _ = Token.objects.get_or_create(user=self.user)
        # Crea un sondaggio globale (senza corso associato)
        SondaggioMattutinoConfig.objects.create(
            corso=None,
            testo="Sondaggio Globale",
            is_active=True
        )
        response = self.client.get(f"/api/export/global/?format=xlsx&token={token.key}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response["Content-Type"],
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )

    def test_duplicate_tessera_associativa_validation(self):
        # 1. Crea primo allievo con tessera 123
        Allievo.objects.create(
            nome="Mario",
            cognome="Rossi",
            ruolo="leader",
            tessera_associativa="123"
        )

        # 2. Tentativo di creare secondo allievo con stessa tessera 123
        serializer = AllievoSerializer(data={
            "nome": "Luigi",
            "cognome": "Verdi",
            "ruolo": "leader",
            "tessera_associativa": "123"
        })
        self.assertFalse(serializer.is_valid())
        self.assertIn("tessera_associativa", serializer.errors)
        self.assertIn("già assegnato", str(serializer.errors["tessera_associativa"]))

        # 3. Aggiornamento dello stesso allievo (nessun errore su se stesso)
        mario = Allievo.objects.get(tessera_associativa="123")
        update_serializer = AllievoSerializer(instance=mario, data={
            "nome": "Mario Modificato",
            "tessera_associativa": "123"
        }, partial=True)
        self.assertTrue(update_serializer.is_valid(), update_serializer.errors)

        # 4. Tessera vuota o whitespace è consentita per più allievi
        serializer_blank = AllievoSerializer(data={
            "nome": "Prospect1",
            "cognome": "Test",
            "ruolo": "leader",
            "is_prospect": True,
            "tessera_associativa": ""
        })
        self.assertTrue(serializer_blank.is_valid(), serializer_blank.errors)


class GeminiPresenceParsingTests(TestCase):
    def setUp(self):
        self.scuola = Scuola.objects.create(nome="Scuola Test", sede="Sede")
        self.corso = Corso.objects.create(scuola=self.scuola, livello="principiante", giorno_settimana="MERCOLEDI", orario=time(19, 30))
        self.allievo = Allievo.objects.create(nome="Danila", cognome="Ghisletti", telefono="39333111222", corso=self.corso)

    def test_single_raising_hand_emoji(self):
        from .gemini_service import parse_and_apply_presenze
        # Even if Gemini returns IGNOTA, heuristic should classify as PRESENTE_SINGOLO
        esito, _, _ = parse_and_apply_presenze(
            allievo=self.allievo,
            prossima_lezione=None,
            risposta_ai="IGNOTA",
            mittente_label="Danila Ghisletti",
            corso=self.corso,
            original_text="🙋‍♀️"
        )
        self.assertEqual(esito, "PRESENTE_SINGOLO")

    def test_single_thumbs_up_emoji(self):
        from .gemini_service import parse_and_apply_presenze
        esito, _, _ = parse_and_apply_presenze(
            allievo=self.allievo,
            prossima_lezione=None,
            risposta_ai="IGNOTA",
            mittente_label="Danila Ghisletti",
            corso=self.corso,
            original_text="👍"
        )
        self.assertEqual(esito, "PRESENTE_SINGOLO")

    def test_couple_raising_hands_emojis(self):
        from .gemini_service import parse_and_apply_presenze
        esito, _, _ = parse_and_apply_presenze(
            allievo=self.allievo,
            prossima_lezione=None,
            risposta_ai="IGNOTA",
            mittente_label="Rosanna Perozzo",
            corso=self.corso,
            original_text="🙋🏼‍♀️🙋🏻‍♂️"
        )
        self.assertEqual(esito, "PRESENTE_COPPIA")

    def test_negative_with_emoji_not_present(self):
        from .gemini_service import parse_and_apply_presenze
        esito, _, _ = parse_and_apply_presenze(
            allievo=self.allievo,
            prossima_lezione=None,
            risposta_ai="ASSENTE_SINGOLO",
            mittente_label="Danila Ghisletti",
            corso=self.corso,
            original_text="Stasera non riesco 👍"
        )
        self.assertEqual(esito, "ASSENTE_SINGOLO")






    def test_sollecito_skips_jolly(self):
        from .tasks import controlla_e_invia_solleciti_mancata_risposta
        from .models import Lezione, Presenza, SondaggioMattutinoConfig
        from datetime import date
        from unittest.mock import patch

        cfg = SondaggioMattutinoConfig.objects.create(sollecito_attivo=True, sollecito_orario='00:00')
        lezione = Lezione.objects.create(corso=self.corso, data=date.today())
        
        # Allievo 1: normale del corso, senza risposta
        p1, _ = Presenza.objects.get_or_create(lezione=lezione, allievo=self.allievo)
        p1.presente = None
        p1.is_jolly = False
        p1.save()
        
        # Allievo 2: Jolly, senza risposta
        jolly_allievo = Allievo.objects.create(nome='Jolly', cognome='Test', telefono='39333999888', corso=self.corso)
        p2, _ = Presenza.objects.get_or_create(lezione=lezione, allievo=jolly_allievo)
        p2.presente = None
        p2.is_jolly = True
        p2.save()

        with patch('core.tasks.send_whatsapp_message') as mock_send:
            mock_send.return_value = {'success': True}
            res = controlla_e_invia_solleciti_mancata_risposta(lezione_id=lezione.id, force=True)
            
            # Solo l'allievo normale deve essere stato sollecitato, MAI il jolly
            phones_called = [call.kwargs['to'] for call in mock_send.call_args_list]
            self.assertIn('39333111222', phones_called)
            self.assertNotIn('39333999888', phones_called)


class AnalisiCertificatoMedicoTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username="test_cert", password="secret")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.allievo = Allievo.objects.create(
            nome="Luca",
            cognome="Verdi",
            telefono="393481234567"
        )

    def test_analizza_certificato_medico_heuristic_explicit_scadenza(self):
        from .gemini_service import _heuristic_analyze_certificate_text
        text = "Certificato medico sportivo non agonistico per Luca Verdi. Rilasciato il 10/11/2026. Data di scadenza: 10/11/2027."
        res = _heuristic_analyze_certificate_text(text)
        self.assertIsNotNone(res)
        self.assertEqual(res['data_scadenza'], '2027-11-10')
        self.assertEqual(res['data_scadenza_italiana'], '10/11/2027')
        self.assertEqual(res['data_rilascio'], '2026-11-10')

    def test_analizza_certificato_medico_heuristic_annual_rule(self):
        from .gemini_service import _heuristic_analyze_certificate_text
        # Solo data di rilascio/visita con citazione normativa D.M. 24/04/2013
        text = "Si rilascia certificato di idoneità non agonistica in data 15/09/2026 ex D.M. 24/04/2013."
        res = _heuristic_analyze_certificate_text(text)
        self.assertIsNotNone(res)
        # La scadenza deve essere calcolata a +1 anno dal 15/09/2026 -> 15/09/2027 (e non dal 2013!)
        self.assertEqual(res['data_scadenza'], '2027-09-15')
        self.assertEqual(res['data_scadenza_italiana'], '15/09/2027')
        self.assertEqual(res['data_rilascio'], '2026-09-15')

    def test_api_analizza_certificato_medico_endpoint(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        from unittest.mock import patch

        fake_file = SimpleUploadedFile("certificato.txt", b"Certificato medico. Visita effettuata il 05/06/2026.", content_type="text/plain")
        res = self.client.post(
            f"/api/allievi/{self.allievo.id}/analizza-certificato-medico/",
            {'files': [fake_file]},
            format='multipart'
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertTrue(data['found'])
        self.assertEqual(data['data_scadenza'], '2027-06-05')
        self.assertEqual(data['data_scadenza_italiana'], '05/06/2027')
        self.assertEqual(data['source'], 'ocr_locale')

    def test_import_documento_drive_saves_italian_format_date(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        from unittest.mock import MagicMock
        from .models import GoogleDriveConfig

        # Crea configurazione Google Drive valida
        GoogleDriveConfig.objects.all().delete()
        GoogleDriveConfig.objects.create(
            auth_type='oauth',
            oauth_refresh_token='mock_token',
            folder_certificati_id='folder_123',
            folder_certificati_nome='Certificati'
        )

        with patch("core.api_views.get_google_drive_service") as mock_get_service:
            mock_service = MagicMock()
            mock_files = MagicMock()
            mock_files.create.return_value.execute.return_value = {'id': 'drive_file_1', 'name': 'test.pdf', 'webViewLink': 'http://drive/link'}
            mock_service.files.return_value = mock_files
            mock_get_service.return_value = mock_service

            import io
            import pypdf
            writer = pypdf.PdfWriter()
            writer.add_blank_page(width=72, height=72)
            pdf_buf = io.BytesIO()
            writer.write(pdf_buf)

            fake_file = SimpleUploadedFile("certificato.pdf", pdf_buf.getvalue(), content_type="application/pdf")
            res = self.client.post(
                f"/api/allievi/{self.allievo.id}/import-documento-drive/",
                {
                    'tipo_documento': 'certificati',
                    'scadenza_certificato_medico': '25/12/2027', # Formato italiano DD/MM/YYYY
                    'files': [fake_file],
                },
                format='multipart'
            )
            self.assertEqual(res.status_code, 200)
            self.allievo.refresh_from_db()
            self.assertEqual(self.allievo.scadenza_certificato_medico, date(2027, 12, 25))


class LibroSociTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='admin', password='password123')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_br001_sync_allievo_to_socio(self):
        """BR-001: Allievo con tessera_associativa crea automaticamente un Socio con categoria ORDINARIO e origine STUDENTE."""
        allievo = Allievo.objects.create(
            nome='Mario',
            cognome='Rossi',
            codice_fiscale='RSSMRA80A01H501U',
            tessera_associativa='TS100',
            telefono='3331234567',
            email='mario.rossi@example.com',
            comune_residenza='Milano',
            provincia_residenza='MI',
            indirizzo_residenza='Via Roma 1',
            data_ammissione=date(2026, 1, 15)
        )

        socio = Socio.objects.filter(allievo=allievo).first()
        self.assertIsNotNone(socio)
        self.assertEqual(socio.numero_tessera, 'TS100')
        self.assertEqual(socio.cognome, 'Rossi')
        self.assertEqual(socio.nome, 'Mario')
        self.assertEqual(socio.categoria, CategoriaSocio.ORDINARIO)
        self.assertEqual(socio.quota_associativa, Decimal('20.00'))
        self.assertEqual(socio.origine, OrigineSocio.STUDENTE)
        self.assertTrue(socio.attivo)
        self.assertEqual(socio.data_iscrizione, date(2026, 1, 15))
        self.assertIn('Milano', socio.indirizzo_residenza)

        # Modifica allievo sincronizza i dati
        allievo.cognome = 'Rossi Bianchi'
        allievo.telefono = '3339999999'
        allievo.save()

        socio.refresh_from_db()
        self.assertEqual(socio.cognome, 'Rossi Bianchi')
        self.assertEqual(socio.telefono, '3339999999')

    def test_br001_socio_studente_non_eliminabile(self):
        """BR-001: I soci derivati da allievi non possono essere eliminati direttamente dal Libro Soci."""
        allievo = Allievo.objects.create(
            nome='Giuseppe',
            cognome='Verdi',
            tessera_associativa='TS101',
            telefono='3332221111'
        )
        socio = Socio.objects.get(allievo=allievo)

        res = self.client.delete(f'/api/soci/{socio.id}/')
        self.assertEqual(res.status_code, 400)
        self.assertTrue(Socio.objects.filter(id=socio.id).exists())

    def test_br002_socio_manuale_creazione_ed_eliminazione(self):
        """BR-002: Creazione socio manuale ed eliminazione consentita."""
        payload = {
            'numero_tessera': 'TS_MAN_01',
            'cognome': 'Bianchi',
            'nome': 'Luigi',
            'codice_fiscale': 'BNCLGU85M01H501Z',
            'categoria': 'SOSTENITORE',
            'quota_associativa': '30.00',
            'data_iscrizione': '2026-02-01',
            'origine': 'MANUALE'
        }
        res = self.client.post('/api/soci/', payload, format='json')
        self.assertEqual(res.status_code, 201)
        socio_id = res.data['id']
        socio = Socio.objects.get(id=socio_id)
        self.assertEqual(socio.origine, OrigineSocio.MANUALE)
        self.assertEqual(socio.categoria, CategoriaSocio.SOSTENITORE)
        self.assertEqual(socio.quota_associativa, Decimal('30.00'))

        # Eliminazione socio manuale
        del_res = self.client.delete(f'/api/soci/{socio_id}/')
        self.assertEqual(del_res.status_code, 204)
        self.assertFalse(Socio.objects.filter(id=socio_id).exists())

    def test_ordinamento_per_numero_tessera(self):
        """Punto 2: Ordinamento numerico predefinito dei soci per numero tessera."""
        Socio.objects.create(numero_tessera='10', cognome='Dieci', nome='A', origine=OrigineSocio.MANUALE)
        Socio.objects.create(numero_tessera='2', cognome='Due', nome='B', origine=OrigineSocio.MANUALE)
        Socio.objects.create(numero_tessera='1', cognome='Uno', nome='C', origine=OrigineSocio.MANUALE)
        res = self.client.get('/api/soci/?ordering=numero_tessera')
        self.assertEqual(res.status_code, 200)
        items = res.json()
        numeric_tessere = [s['numero_tessera'] for s in items if s['numero_tessera'] in ['1', '2', '10']]
        self.assertEqual(numeric_tessere, ['1', '2', '10'])

        # Ordinamento decrescente
        res_desc = self.client.get('/api/soci/?ordering=-numero_tessera')
        self.assertEqual(res_desc.status_code, 200)
        items_desc = res_desc.json()
        numeric_desc = [s['numero_tessera'] for s in items_desc if s['numero_tessera'] in ['1', '2', '10']]
        self.assertEqual(numeric_desc, ['10', '2', '10'][:1] + ['2', '1'])

    def test_azzeramento_quota_associativa(self):
        """Punto 4: Azzeramento quota associativa salvato a 0.00."""
        socio = Socio.objects.create(
            numero_tessera='999', cognome='Test', nome='Quota', quota_associativa=Decimal('20.00'), origine=OrigineSocio.MANUALE
        )
        # Azzeramento con 0.00
        res = self.client.patch(f'/api/soci/{socio.id}/', {'quota_associativa': 0.0}, format='json')
        self.assertEqual(res.status_code, 200)
        socio.refresh_from_db()
        self.assertEqual(socio.quota_associativa, Decimal('0.00'))

        # Azzeramento con null
        res2 = self.client.patch(f'/api/soci/{socio.id}/', {'quota_associativa': None}, format='json')
        self.assertEqual(res2.status_code, 200)
        socio.refresh_from_db()
        self.assertEqual(socio.quota_associativa, Decimal('0.00'))

    def test_sync_socio_to_allievo(self):
        """Punto 4: Se vengono modificati i dati del socio, la modifica viene riportata pure sull'allievo."""
        allievo = Allievo.objects.create(
            nome='Luigi',
            cognome='Bianchi',
            tessera_associativa='TS200',
            telefono='3331112233',
            email='luigi@test.com'
        )
        socio = Socio.objects.get(allievo=allievo)

        # Modifica tramite API PUT del socio
        payload = {
            'numero_tessera': 'TS200_NEW',
            'cognome': 'Bianchi Verdi',
            'nome': 'Luigi Mario',
            'telefono': '3339998877',
            'email': 'luigi.new@test.com',
            'categoria': 'ORDINARIO',
            'quota_associativa': '20.00',
            'indirizzo_residenza': 'Via Garibaldi 5, Milano (MI)',
        }
        res = self.client.put(f'/api/soci/{socio.id}/', payload, format='json')
        self.assertEqual(res.status_code, 200)

        # Verifica sincronizzazione su allievo
        allievo.refresh_from_db()
        self.assertEqual(allievo.cognome, 'Bianchi Verdi')
        self.assertEqual(allievo.nome, 'Luigi Mario')
        self.assertEqual(allievo.telefono, '3339998877')
        self.assertEqual(allievo.email, 'luigi.new@test.com')
        self.assertEqual(allievo.tessera_associativa, 'TS200_NEW')
        self.assertEqual(allievo.indirizzo_residenza, 'Via Garibaldi 5, Milano (MI)')

    def test_cessazione_socio(self):
        """Test cessazione socio."""
        socio = Socio.objects.create(
            numero_tessera='T3',
            cognome='Neri',
            nome='Franco',
            origine=OrigineSocio.MANUALE
        )
        self.assertTrue(socio.attivo)

        res = self.client.post(
            f'/api/soci/{socio.id}/cessazione/',
            {
                'data_cessazione': '2026-06-30',
                'motivo_cessazione': 'RECESSO'
            },
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        socio.refresh_from_db()
        self.assertFalse(socio.attivo)
        self.assertEqual(socio.data_cessazione, date(2026, 6, 30))
        self.assertEqual(socio.motivo_cessazione, MotivoCessazione.RECESSO)

    def test_export_xls(self):
        """Test esportazione XLSX del Libro Soci."""
        Socio.objects.create(
            numero_tessera='T_EXP',
            cognome='ExportTest',
            nome='Nome',
            origine=OrigineSocio.MANUALE
        )
        res = self.client.get('/api/soci/export/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res['Content-Type'], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertTrue(len(res.content) > 1000)

    def test_export_xls_with_token_query_param(self):
        """Test esportazione XLSX del Libro Soci via query param token per download da browser."""
        from rest_framework.authtoken.models import Token
        token, _ = Token.objects.get_or_create(user=self.user)
        unauth_client = APIClient()
        res = unauth_client.get(f'/api/soci/export/?token={token.key}')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res['Content-Type'], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertTrue(len(res.content) > 1000)

    def test_export_xls_columns(self):
        """Test colonne Excel del Libro Soci: include Residenza ed esclude Origine."""
        import openpyxl
        import io
        Socio.objects.create(
            numero_tessera='T_COL',
            cognome='ColTest',
            nome='Nome',
            indirizzo_residenza='Via Dante 10, Roma (RM)',
            origine=OrigineSocio.MANUALE
        )
        res = self.client.get('/api/soci/export/')
        self.assertEqual(res.status_code, 200)
        wb = openpyxl.load_workbook(io.BytesIO(res.content))
        ws = wb.active
        headers = [cell.value for cell in ws[1]]
        self.assertIn("Residenza", headers)
        self.assertNotIn("Origine", headers)

    def test_soci_senza_allievo_e_reiscrizione(self):
        """Test filtro senza_allievo=true e reiscrizione da socio con conservazione tessera."""
        import time
        allievo_attivo = Allievo.objects.create(
            nome='Attivo',
            cognome='Test',
            tessera_associativa='101',
        )
        ex_allievo = Allievo.objects.create(
            nome='Ex',
            cognome='Allievo',
            tessera_associativa='102',
        )
        socio_ex = Socio.objects.get(numero_tessera='102')
        ex_allievo.delete()
        socio_ex.refresh_from_db()
        self.assertIsNone(socio_ex.allievo)

        res = self.client.get('/api/soci/?senza_allievo=true')
        self.assertEqual(res.status_code, 200)
        results = res.data if isinstance(res.data, list) else res.data.get('results', [])
        tessere = [s['numero_tessera'] for s in results]
        self.assertIn('102', tessere)
        self.assertNotIn('101', tessere)

        # Garantisce created_at successivo al socio esistente
        time.sleep(0.02)
        scuola = Scuola.objects.create(nome='Scuola Test')
        corso = Corso.objects.create(
            scuola=scuola,
            livello='principiante',
            orario='20:00:00',
            giorno_settimana='LUNEDI',
        )
        # Reiscrizione come prospect con la stessa tessera
        res_create = self.client.post('/api/allievi/', {
            'nome': 'Ex',
            'cognome': 'Allievo',
            'is_prospect': True,
            'tessera_associativa': '102',
            'corso': str(corso.id),
        }, format='json')
        self.assertEqual(res_create.status_code, 201)
        new_id = res_create.data['id']
        socio_ex.refresh_from_db()
        self.assertEqual(str(socio_ex.allievo_id), str(new_id))

        # Conversione del prospect in allievo effettivo deve preservare la tessera del socio preesistente
        res_conv = self.client.post(f'/api/allievi/{new_id}/convert-status/', {
            'corso_id': str(corso.id),
        }, format='json')
        self.assertEqual(res_conv.status_code, 200)
        re_enrolled = Allievo.objects.get(id=new_id)
        self.assertFalse(re_enrolled.is_prospect)
        self.assertEqual(re_enrolled.tessera_associativa, '102')
        self.assertNotEqual(allievo_attivo.id, re_enrolled.id)

    def test_next_tessera_considera_anche_soci_manuali(self):
        """Il suggerimento della prossima tessera deve considerare anche i numeri presenti nel Libro Soci."""
        Socio.objects.create(
            numero_tessera='250',
            cognome='Manuale',
            nome='Max',
            origine=OrigineSocio.MANUALE,
        )
        res = self.client.get('/api/allievi/next-tessera-associativa/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['next_tessera_associativa'], '251')

    def test_tessera_associativa_template_pdf_e_whatsapp(self):
        """Test generazione PDF tessera associativa da template e invio via WhatsApp."""
        import pymupdf
        from django.core.files.base import ContentFile
        from unittest.mock import patch
        from .models import DocumentTemplate

        # Crea un template PDF vuoto A4 con le etichette del retro tessera
        doc = pymupdf.open()
        page = doc.new_page(width=595.28, height=841.89)
        page.insert_text(pymupdf.Point(100, 515), "Numero:")
        page.insert_text(pymupdf.Point(100, 565), "Nome:")
        page.insert_text(pymupdf.Point(100, 615), "Cognome:")
        page.insert_text(pymupdf.Point(100, 665), "Tessera ACSI associata:")
        tmpl_bytes = doc.tobytes()
        doc.close()

        tmpl, _ = DocumentTemplate.objects.get_or_create(
            chiave='tessera_associativa',
            defaults={'nome': 'Tessera Associativa'}
        )
        tmpl.file.save('test_tessera.pdf', ContentFile(tmpl_bytes), save=True)

        socio = Socio.objects.create(
            numero_tessera='4',
            numero_tessera_acsi='PS7546012',
            cognome='Avolio',
            nome='Rocco',
            telefono='+39 333 123 4567',
            origine=OrigineSocio.MANUALE,
        )

        # 1. Verifica list document-templates contenga tessera_associativa
        res_list = self.client.get('/api/document-templates/')
        self.assertEqual(res_list.status_code, 200)
        chiavi = [t['chiave'] for t in (res_list.data if isinstance(res_list.data, list) else res_list.data.get('results', []))]
        self.assertIn('tessera_associativa', chiavi)

        # 2. Verifica endpoint tessera-pdf
        res_pdf = self.client.get(f'/api/soci/{socio.id}/tessera-pdf/')
        self.assertEqual(res_pdf.status_code, 200)
        self.assertEqual(res_pdf['Content-Type'], 'application/pdf')
        compiled_doc = pymupdf.open(stream=res_pdf.content, filetype='pdf')
        text = compiled_doc[0].get_text()
        compiled_doc.close()
        self.assertIn('4', text)
        self.assertIn('Rocco', text)
        self.assertIn('Avolio', text)
        self.assertIn('PS7546012', text)

        # 3. Verifica endpoint send-tessera-whatsapp
        with patch('core.wa_client.send_whatsapp_document', return_value={'success': True}) as mock_wa:
            res_wa = self.client.post(
                f'/api/soci/{socio.id}/send-tessera-whatsapp/',
                {'telefono': '+39 333 123 4567', 'messaggio': 'Ecco la tua tessera'},
                format='json',
            )
        self.assertEqual(res_wa.status_code, 200)
        self.assertTrue(res_wa.data['success'])
        mock_wa.assert_called_once()
        tmpl.file.delete(save=False)

    def test_verbale_ammissione_socio_date_e_pdf(self):
        """Test elenco date iscrizione e generazione PDF Verbale di Ammissione Socio."""
        import pymupdf
        from django.core.files.base import ContentFile
        from .models import DocumentTemplate

        # Crea template PDF a 2 pagine con i placeholder reali (incluso quello wrappato)
        doc = pymupdf.open()
        p1 = doc.new_page(width=595.28, height=841.89)
        p1.insert_text(pymupdf.Point(56, 50), "Tanto Tango ASD")
        p1.insert_text(pymupdf.Point(56, 130), "Verbale del Consiglio direttivo")
        p1.insert_text(pymupdf.Point(56, 160), "L’anno <anno>, il giorno <giorno> del mese di <mese> alle ore 20:00.")
        p1.insert_text(pymupdf.Point(56, 200), "Punto 1")
        p1.insert_text(pymupdf.Point(56, 220), "<elenco_allievi_con_nome_cognome_data_nascita_comune_nascita_provi")
        p1.insert_text(pymupdf.Point(56, 234), "ncia_nascita>")
        p1.insert_text(pymupdf.Point(56, 270), "DELIBERA")
        p1.insert_text(pymupdf.Point(56, 290), "<elenco_allievi_con_nome_cognome >")
        p1.insert_text(pymupdf.Point(56, 330), "demandando al Presidente gli adempimenti.")

        p2 = doc.new_page(width=595.28, height=841.89)
        p2.insert_text(pymupdf.Point(56, 50), "Tanto Tango ASD")
        p2.insert_text(pymupdf.Point(56, 180), "Letto, confermato e sottoscritto.")
        p2.insert_text(pymupdf.Point(100, 220), "il Segretario")
        p2.insert_text(pymupdf.Point(360, 220), "il Presidente")
        tmpl_bytes = doc.tobytes()
        doc.close()

        tmpl, _ = DocumentTemplate.objects.get_or_create(
            chiave='verbale_ammissione_socio',
            defaults={'nome': 'Verbale di Ammissione Socio'},
        )
        tmpl.file.save('test_verbale_amm.pdf', ContentFile(tmpl_bytes), save=True)

        Socio.objects.create(
            numero_tessera='10',
            cognome='Avolio',
            nome='Rocco',
            data_nascita=date(1982, 5, 10),
            luogo_nascita='Corigliano Calabro (CS)',
            codice_fiscale='VLARCC82E10D005X',
            data_iscrizione=date(2026, 10, 22),
            origine=OrigineSocio.MANUALE,
        )
        Socio.objects.create(
            numero_tessera='11',
            cognome='D’Ingianna',
            nome='Francesca',
            data_nascita=date(1977, 3, 8),
            luogo_nascita='Melito di Porto Salvo (RC)',
            codice_fiscale='DNGFNC77C48F112Y',
            data_iscrizione=date(2026, 10, 22),
            origine=OrigineSocio.MANUALE,
        )

        res_dates = self.client.get('/api/soci/date-iscrizione/')
        self.assertEqual(res_dates.status_code, 200)
        dates = res_dates.data['dates']
        self.assertTrue(any(d['date'] == '2026-10-22' and d['count'] == 2 for d in dates))

        res_pdf = self.client.get('/api/soci/verbale-ammissione-pdf/?data_iscrizione=2026-10-22')
        self.assertEqual(res_pdf.status_code, 200)
        self.assertEqual(res_pdf['Content-Type'], 'application/pdf')

        compiled = pymupdf.open(stream=res_pdf.content, filetype='pdf')
        full_out = "\n".join(p.get_text() for p in compiled).replace('\xa0', ' ')
        compiled.close()

        self.assertIn('2026', full_out)
        self.assertIn('22', full_out)
        self.assertIn('Ottobre', full_out)
        self.assertIn('Rocco Avolio, nato a Corigliano Calabro (CS) il 10/05/1982', full_out)
        self.assertIn("Francesca D'Ingianna, nata a Melito di Porto Salvo (RC) il 08/03/1977", full_out)
        tmpl.file.delete(save=False)

