import os
import unittest
from unittest.mock import patch, Mock

import server


class ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.client = server.app.test_client()
        server._sessions.clear()
        self.body = {"auth_code": "single-use-code", "request_id": "637b7841-c86d-4d17-99c4-c9e23b17317f"}

    def test_no_google_identity_before_verified(self):
        with patch.object(server, "verify_code", side_effect=ValueError()):
            response = self.client.post("/auth/google", json=self.body)
        self.assertEqual(response.status_code, 401)
        self.assertNotIn("subject", response.json)
        self.assertEqual(server._sessions, {})

    def test_verified_subject_gets_short_session_and_request_binding(self):
        with patch.object(server, "verify_code", return_value="google-sub-123"):
            response = self.client.post("/auth/google", json=self.body)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["subject"], "google-sub-123")
        self.assertEqual(response.json["request_id"], self.body["request_id"])
        self.assertEqual(response.json["expires_in"], 3600)
        self.assertEqual(response.headers["Cache-Control"], "no-store")
        self.assertGreaterEqual(len(response.json["session_token"]), 32)

    def test_logout_invalidates_server_session(self):
        with patch.object(server, "verify_code", return_value="google-sub-123"):
            token = self.client.post("/auth/google", json=self.body).json["session_token"]
        self.assertEqual(len(server._sessions), 1)
        result = self.client.post("/auth/google/logout", headers={"Authorization": "Bearer " + token})
        self.assertEqual(result.status_code, 200)
        self.assertEqual(len(server._sessions), 0)

    def test_invalid_request_never_reaches_google(self):
        for body in ({}, {"auth_code": "x", "request_id": "invalid"}, {"auth_code": "x" * 5000, "request_id": self.body["request_id"]}):
            with self.subTest(body_type=list(body)), patch.object(server, "verify_code") as verify:
                self.assertEqual(self.client.post("/auth/google", json=body).status_code, 400)
                verify.assert_not_called()

    def test_server_exception_not_leaked(self):
        with patch.object(server, "verify_code", side_effect=Exception("SECRET")):
            response = self.client.post("/auth/google", json=self.body)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("SECRET", response.text)

    @patch.dict(os.environ, {"GOOGLE_WEB_CLIENT_ID": "web.apps.googleusercontent.com", "GOOGLE_WEB_CLIENT_SECRET": "server-only"})
    def test_exchange_checks_audience_using_official_verifier(self):
        provider = Mock(status_code=200)
        provider.json.return_value = {"id_token": "signed-token"}
        with patch.object(server.requests, "post", return_value=provider) as exchange, patch.object(server.id_token, "verify_oauth2_token", return_value={"sub": "123"}) as verify:
            self.assertEqual(server.verify_code("once"), "123")
        self.assertEqual(verify.call_args.kwargs["audience"], "web.apps.googleusercontent.com")
        self.assertFalse(exchange.call_args.kwargs["allow_redirects"])

    @patch.dict(os.environ, {"GOOGLE_WEB_CLIENT_ID": "web.apps.googleusercontent.com", "GOOGLE_WEB_CLIENT_SECRET": "server-only"})
    def test_pgs_access_token_alone_is_not_game_identity(self):
        provider = Mock(status_code=200)
        provider.json.return_value = {"access_token": "pgs-token"}
        with patch.object(server.requests, "post", return_value=provider), self.assertRaises(ValueError):
            server.verify_code("once")

    @patch.dict(os.environ, {"GOOGLE_WEB_CLIENT_ID": "web.apps.googleusercontent.com", "GOOGLE_WEB_CLIENT_SECRET": "server-only"})
    def test_google_rejecting_code_is_not_success(self):
        with patch.object(server.requests, "post", return_value=Mock(status_code=400)), self.assertRaises(ValueError):
            server.verify_code("replayed")

    @patch.dict(os.environ, {"GOOGLE_WEB_CLIENT_ID": "web.apps.googleusercontent.com", "GOOGLE_WEB_CLIENT_SECRET": "server-only", "GOOGLE_ANDROID_CLIENT_IDS": "android.apps.googleusercontent.com"})
    def test_hybrid_presenter_requires_explicit_allowlist(self):
        provider = Mock(status_code=200)
        provider.json.return_value = {"id_token": "signed-token"}
        with patch.object(server.requests, "post", return_value=provider), patch.object(server.id_token, "verify_oauth2_token", return_value={"sub": "123", "azp": "android.apps.googleusercontent.com"}):
            self.assertEqual(server.verify_code("once"), "123")
        with patch.object(server.requests, "post", return_value=provider), patch.object(server.id_token, "verify_oauth2_token", return_value={"sub": "123", "azp": "foreign.apps.googleusercontent.com"}), self.assertRaises(ValueError):
            server.verify_code("once")

    def test_google_certificate_fetch_timeout_is_bounded(self):
        session = Mock()
        server.BoundedGoogleRequest(session=session)(url="https://www.googleapis.com/oauth2/v1/certs")
        self.assertEqual(session.request.call_args.kwargs["timeout"], (5, 10))


if __name__ == "__main__":
    unittest.main()
