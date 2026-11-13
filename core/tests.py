from datetime import date, time
from unittest.mock import patch, MagicMock
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Allievo, Corso, Scuola
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




