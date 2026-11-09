#!/usr/bin/env python3
"""Sinh collection Postman kiểm thử billing, chat, discovery và media service qua API Gateway.

Chạy lại sau khi sửa: python3 postman/tools/build_service_tests.py
Kết quả: postman/Animal-Locket-Service-Tests.postman_collection.json
"""
import json
import pathlib
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Animal-Locket-Service-Tests.postman_collection.json"
API = "{{api_base_url}}"

# Đoạn kiểm tra dùng lại: lỗi RFC 7807 có trường code ổn định.
PROBLEM = """function expectProblem(status, code) {
  pm.test(`Status ${status}`, () => pm.response.to.have.status(status));
  if (code) {
    pm.test(`Problem code ${code}`, () => pm.expect(pm.response.json().code).to.eql(code));
  }
}"""


def lines(text):
    return [line for line in text.strip("\n").split("\n")]


def request(name, method, path, tests, body=None, prerequest=None, auth=True, headers=None, raw_url=False,
            description=None):
    url = path if raw_url else f"{API}{path}"
    req = {"method": method, "header": [], "url": url}
    if description:
        req["description"] = description
    if body is not None:
        req["header"].append({"key": "Content-Type", "value": "application/json"})
        req["body"] = {"mode": "raw", "raw": body if isinstance(body, str) else json.dumps(body, indent=2),
                       "options": {"raw": {"language": "json"}}}
    for k, v in (headers or {}).items():
        req["header"].append({"key": k, "value": v})
    if not auth:
        req["auth"] = {"type": "noauth"}
    events = []
    if prerequest:
        events.append({"listen": "prerequest", "script": {"type": "text/javascript", "exec": lines(prerequest)}})
    events.append({"listen": "test", "script": {"type": "text/javascript", "exec": lines(PROBLEM + "\n" + tests)}})
    return {"name": name, "event": events, "request": req}


def folder(name, description, items):
    return {"name": name, "description": description, "item": items}


# ---------------------------------------------------------------- 00 Setup
setup = folder("00 - Setup", "Lấy publicId của tài khoản test và một người bạn. Tài khoản test phải có sẵn ít nhất một bạn (xem docs/05-service-tests.md).", [
    request("Gateway rejects missing JWT", "GET", "/api/v1/billing/me", auth=False, tests="""
pm.test('Status 401 without bearer token', () => pm.response.to.have.status(401));
"""),
    request("Load my profile", "GET", "/api/v1/users/me", tests="""
pm.test('Status 200 (token still valid?)', () => pm.response.to.have.status(200));
const me = pm.response.json();
pm.test('Profile has publicId', () => pm.expect(me.publicId).to.match(/^[a-z2-7]{20}$/));
pm.collectionVariables.set('my_public_id', me.publicId);
"""),
    request("Load a friend for chat/discovery", "GET", "/api/v1/friends", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const friends = pm.response.json();
pm.test('Friends is an array', () => pm.expect(friends).to.be.an('array'));
pm.test('At least one friend for chat tests', () => pm.expect(friends.length).to.be.above(0));
if (friends.length) pm.collectionVariables.set('friend_public_id', friends[0].publicId);
"""),
])

# ---------------------------------------------------------------- 01 Media
media = folder("01 - media-service", "Luồng tải ảnh: xin URL ký sẵn → PUT file lên R2 → complete → đọc trạng thái và URL xem.", [
    request("Upload rejects unsupported content type", "POST", "/api/v1/media/uploads",
            body={"context": "CHAT", "contentType": "image/gif", "sizeBytes": 1024},
            tests="expectProblem(400, 'UNSUPPORTED_MEDIA_TYPE');"),
    request("Upload rejects file over size limit", "POST", "/api/v1/media/uploads",
            body={"context": "CHAT", "contentType": "image/png", "sizeBytes": 20000000},
            tests="expectProblem(400, 'FILE_TOO_LARGE');"),
    request("Upload rejects missing context", "POST", "/api/v1/media/uploads",
            body={"contentType": "image/png", "sizeBytes": 1024},
            tests="expectProblem(400);"),
    request("Upload rejects sizeBytes = 0", "POST", "/api/v1/media/uploads",
            body={"context": "CHAT", "contentType": "image/png", "sizeBytes": 0},
            tests="expectProblem(400);"),
    request("Request upload ticket (PNG)", "POST", "/api/v1/media/uploads",
            body='{\n  "context": "CHAT",\n  "contentType": "image/png",\n  "sizeBytes": {{fixture_png_size}}\n}',
            tests="""
pm.test('Status 201', () => pm.response.to.have.status(201));
const t = pm.response.json();
pm.test('Ticket has mediaId (UUID)', () => pm.expect(t.mediaId).to.match(/^[0-9a-f-]{36}$/));
pm.test('Ticket has signed upload URL', () => pm.expect(t.uploadUrl).to.match(/^https?:\\/\\//));
pm.test('Ticket requires Content-Type image/png', () => pm.expect(t.headers['Content-Type']).to.eql('image/png'));
pm.test('Ticket expires in the future', () => pm.expect(t.expiresInSeconds).to.be.above(0));
pm.collectionVariables.set('media_id', t.mediaId);
pm.collectionVariables.set('upload_url', t.uploadUrl);
"""),
    request("Complete before upload is rejected", "POST", "/api/v1/media/{{media_id}}/complete",
            tests="expectProblem(409, 'NOT_UPLOADED');"),
    {
        "name": "PUT image to signed URL",
        "event": [{"listen": "test", "script": {"type": "text/javascript", "exec": lines("""
pm.test('Object storage accepts the upload', () => pm.response.to.have.status(200));
""")}}],
        "request": {
            "auth": {"type": "noauth"},
            "method": "PUT",
            "header": [{"key": "Content-Type", "value": "image/png"}],
            "body": {"mode": "file", "file": {"src": "fixtures/test-image.png"}},
            "url": "{{upload_url}}",
            "description": "Postman app: chọn lại file postman/fixtures/test-image.png ở tab Body nếu báo thiếu file.",
        },
    },
    request("Complete upload", "POST", "/api/v1/media/{{media_id}}/complete", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const s = pm.response.json();
pm.test('Same mediaId', () => pm.expect(s.mediaId).to.eql(pm.collectionVariables.get('media_id')));
pm.test('Image is READY (no face worker, raw→public)', () => pm.expect(s.status).to.eql('READY'));
"""),
    request("Get media status", "GET", "/api/v1/media/{{media_id}}", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const s = pm.response.json();
pm.test('Status body matches', () => {
  pm.expect(s.mediaId).to.eql(pm.collectionVariables.get('media_id'));
  pm.expect(s.status).to.eql('READY');
});
"""),
    request("Get signed view URL", "GET", "/api/v1/media/{{media_id}}/url", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const v = pm.response.json();
pm.test('View URL is a link', () => pm.expect(v.url).to.match(/^https?:\\/\\//));
pm.test('View URL expires in the future', () => pm.expect(v.expiresInSeconds).to.be.above(0));
"""),
    request("Unknown media returns 404", "GET", "/api/v1/media/00000000-0000-0000-0000-000000000000",
            tests="expectProblem(404, 'NOT_FOUND');"),
    request("Internal media API is not exposed", "GET", "/internal/media/{{media_id}}",
            tests="pm.test('Gateway does not route /internal', () => pm.expect(pm.response.code).to.be.oneOf([401, 403, 404]));"),
])

# ---------------------------------------------------------------- 02 Discovery
def set_discoverable(value):
    return request(f"Turn discovery mode {'on' if value else 'off'} (user-service)", "PATCH", "/api/v1/users/me",
                   body={"discoverable": value}, tests=f"""
pm.test('Status 200', () => pm.response.to.have.status(200));
pm.test('discoverable = {str(value).lower()}', () => pm.expect(pm.response.json().discoverable).to.eql({str(value).lower()}));
""")


discovery = folder("02 - discovery-service",
                   "Vị trí, online, bộ thẻ, quẹt và Boost. Gateway giới hạn discovery 2 request/giây (burst 10): "
                   "chạy newman với --delay-request 600.", [
    set_discoverable(False),
    request("Location requires discovery mode", "PUT", "/api/v1/discovery/location", body={"lat": 16.0544, "lon": 108.2022},
            tests="expectProblem(403, 'FORBIDDEN');"),
    request("Card deck requires discovery mode", "GET", "/api/v1/discovery/cards?limit=5",
            tests="expectProblem(403, 'FORBIDDEN');"),
    request("Boost requires discovery mode", "POST", "/api/v1/discovery/boost",
            tests="expectProblem(403, 'FORBIDDEN');"),
    set_discoverable(True),
    request("Update location", "PUT", "/api/v1/discovery/location", body={"lat": 16.0544, "lon": 108.2022},
            tests="pm.test('Status 204', () => pm.response.to.have.status(204));"),
    request("Location rejects latitude > 90", "PUT", "/api/v1/discovery/location", body={"lat": 95, "lon": 108.2},
            tests="expectProblem(400);"),
    request("Location rejects missing lon", "PUT", "/api/v1/discovery/location", body={"lat": 16.05},
            tests="expectProblem(400);"),
    request("Heartbeat", "POST", "/api/v1/discovery/heartbeat",
            tests="pm.test('Status 204', () => pm.response.to.have.status(204));"),
    request("Presence of me and friend", "GET", "/api/v1/discovery/presence?ids={{my_public_id}},{{friend_public_id}}",
            tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const online = pm.response.json().online;
pm.test('Presence is a map', () => pm.expect(online).to.be.an('object'));
pm.test('Friend status is reported', () => pm.expect(online[pm.collectionVariables.get('friend_public_id')]).to.be.a('boolean'));
pm.test('Only friends are reported (not myself)', () => pm.expect(online).to.not.have.property(pm.collectionVariables.get('my_public_id')));
"""),
    request("Presence requires ids", "GET", "/api/v1/discovery/presence", tests="expectProblem(400);"),
    request("Card deck", "GET", "/api/v1/discovery/cards?limit=5", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const d = pm.response.json();
pm.test('Deck shape', () => {
  pm.expect(d.cards).to.be.an('array');
  pm.expect(d.degraded).to.be.a('boolean');
  pm.expect(d.swipesLeftToday).to.be.a('number');
});
pm.test('At most 5 cards, never myself', () => {
  pm.expect(d.cards.length).to.be.at.most(5);
  d.cards.forEach(c => pm.expect(c.publicId).to.not.eql(pm.collectionVariables.get('my_public_id')));
});
pm.test('Cards expose no coordinates', () => d.cards.forEach(c => {
  pm.expect(c).to.not.have.property('lat');
  pm.expect(c).to.not.have.property('lon');
}));
"""),
    request("Swipe on myself is rejected", "POST", "/api/v1/discovery/swipes",
            body='{\n  "targetPublicId": "{{my_public_id}}",\n  "direction": "RIGHT"\n}',
            tests="expectProblem(400, 'SELF_SWIPE');"),
    request("Swipe rejects unknown direction", "POST", "/api/v1/discovery/swipes",
            body='{\n  "targetPublicId": "{{friend_public_id}}",\n  "direction": "UP"\n}',
            tests="expectProblem(400);"),
    request("Swipe left skips", "POST", "/api/v1/discovery/swipes",
            body='{\n  "targetPublicId": "{{friend_public_id}}",\n  "direction": "LEFT"\n}', tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const r = pm.response.json();
pm.test('Result SKIPPED', () => pm.expect(r.result).to.eql('SKIPPED'));
pm.test('swipesLeftToday is a number', () => pm.expect(r.swipesLeftToday).to.be.a('number'));
pm.collectionVariables.set('swipes_left', r.swipesLeftToday);
"""),
    request("Swipe right on a friend does not cost a swipe", "POST", "/api/v1/discovery/swipes",
            body='{\n  "targetPublicId": "{{friend_public_id}}",\n  "direction": "RIGHT"\n}', tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const r = pm.response.json();
pm.test('Result ALREADY_FRIENDS', () => pm.expect(r.result).to.eql('ALREADY_FRIENDS'));
pm.test('Quota unchanged', () => pm.expect(r.swipesLeftToday).to.eql(Number(pm.collectionVariables.get('swipes_left'))));
"""),
    request("Boost spends one Boost or reports none left", "POST", "/api/v1/discovery/boost", tests="""
const boosts = Number(pm.collectionVariables.get('wallet_boost') || 0);
if (boosts > 0) {
  pm.test('Status 204', () => pm.response.to.have.status(204));
} else {
  expectProblem(402, 'NO_BOOST');
}
""", prerequest="""
pm.sendRequest({
  url: pm.variables.replaceIn('{{api_base_url}}/api/v1/billing/me'),
  header: { Authorization: 'Bearer ' + pm.environment.get('access_token') }
}, (err, res) => {
  const wallet = (!err && res.code === 200) ? (res.json().wallet || {}) : {};
  pm.collectionVariables.set('wallet_boost', wallet.BOOST || wallet.boost || 0);
});
"""),
    request("Clear location", "DELETE", "/api/v1/discovery/location",
            tests="pm.test('Status 204', () => pm.response.to.have.status(204));"),
    set_discoverable(False),
])

# ---------------------------------------------------------------- 03 Chat
GLYPH_PRE = """
// Mỗi lần chạy vẽ một hình mới (64 cặp toạ độ) để không trùng hình đã có trong hội thoại.
const pts = [];
const a = Math.random() * 5 + 1, b = Math.random() * 5 + 1, phase = Math.random() * Math.PI;
for (let i = 0; i < 64; i++) {
  const t = (i / 63) * 2 * Math.PI;
  pts.push(Math.round(900 * Math.sin(a * t + phase)), Math.round(900 * Math.sin(b * t)));
}
pm.collectionVariables.set('glyph_points', JSON.stringify(pts));
pm.collectionVariables.set('glyph_mutation_id', pm.variables.replaceIn('{{$guid}}'));
"""
VALID_POINTS = json.dumps([((i * 37) % 2001) - 1000 for i in range(128)])

chat = folder("03 - chat-service", "Hội thoại với bạn bè, từ điển ký hiệu (glyph), tin nhắn và đánh dấu đã đọc.", [
    request("Open conversation with myself is rejected", "POST", "/api/v1/chat/conversations",
            body='{\n  "withPublicId": "{{my_public_id}}"\n}', tests="expectProblem(400, 'SELF_CHAT');"),
    request("Open conversation requires withPublicId", "POST", "/api/v1/chat/conversations",
            body={"withPublicId": ""}, tests="expectProblem(400, 'VALIDATION_FAILED');"),
    request("Open conversation with a stranger is forbidden", "POST", "/api/v1/chat/conversations",
            body={"withPublicId": "aaaaaaaaaaaaaaaaaaaa"},
            tests="pm.test('Not allowed (403/404)', () => pm.expect(pm.response.code).to.be.oneOf([403, 404]));"),
    request("Open conversation with friend", "POST", "/api/v1/chat/conversations",
            body='{\n  "withPublicId": "{{friend_public_id}}"\n}', tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const c = pm.response.json();
pm.test('Conversation has id', () => pm.expect(c.id).to.be.a('string').and.not.empty);
pm.collectionVariables.set('conversation_id', c.id);
"""),
    request("Opening again returns the same conversation", "POST", "/api/v1/chat/conversations",
            body='{\n  "withPublicId": "{{friend_public_id}}"\n}', tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
pm.test('Same id (idempotent)', () => pm.expect(pm.response.json().id).to.eql(pm.collectionVariables.get('conversation_id')));
"""),
    request("List my conversations", "GET", "/api/v1/chat/conversations", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const list = pm.response.json();
pm.test('Is an array', () => pm.expect(list).to.be.an('array'));
pm.test('Contains the opened conversation', () =>
  pm.expect(list.map(c => c.id)).to.include(pm.collectionVariables.get('conversation_id')));
"""),
    request("Glyph rejects wrong number of points", "POST", "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "{{$guid}}",\n  "meaning": "test",\n  "color": "#818CF8",\n  "points": [1, 2, 3]\n}',
            tests="expectProblem(400, 'GLYPH_INVALID_POINTS');"),
    request("Glyph rejects color outside palette", "POST", "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "{{$guid}}",\n  "meaning": "test",\n  "color": "#000000",\n  "points": ' + VALID_POINTS + '\n}',
            tests="expectProblem(400, 'GLYPH_INVALID_COLOR');"),
    request("Glyph rejects empty meaning", "POST", "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "{{$guid}}",\n  "meaning": "",\n  "color": "#818CF8",\n  "points": ' + VALID_POINTS + '\n}',
            tests="expectProblem(400, 'GLYPH_INVALID_MEANING');"),
    request("Glyph rejects non-UUID clientMutationId", "POST", "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "not-a-uuid",\n  "meaning": "test",\n  "color": "#818CF8",\n  "points": ' + VALID_POINTS + '\n}',
            tests="expectProblem(400, 'VALIDATION_FAILED');"),
    request("Create glyph", "POST", "/api/v1/chat/conversations/{{conversation_id}}/glyphs", prerequest=GLYPH_PRE,
            body='{\n  "clientMutationId": "{{glyph_mutation_id}}",\n  "meaning": "postman test",\n  "color": "#34D399",\n  "points": {{glyph_points}},\n  "pointCount": 64\n}',
            tests="""
pm.test('Status 201', () => pm.response.to.have.status(201));
const g = pm.response.json();
pm.test('Glyph fields', () => {
  pm.expect(g.id).to.be.a('string').and.not.empty;
  pm.expect(g.conversationId).to.eql(pm.collectionVariables.get('conversation_id'));
  pm.expect(g.creatorPublicId).to.eql(pm.collectionVariables.get('my_public_id'));
  pm.expect(g.meaning).to.eql('postman test');
  pm.expect(g.color).to.eql('#34D399');
  pm.expect(g.points).to.have.lengthOf(128);
  pm.expect(g.status).to.eql('ACTIVE');
});
pm.collectionVariables.set('glyph_id', g.id);
pm.collectionVariables.set('glyph_revision', g.revision);
"""),
    request("Replaying the same clientMutationId returns the same glyph", "POST",
            "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "{{glyph_mutation_id}}",\n  "meaning": "postman test",\n  "color": "#34D399",\n  "points": {{glyph_points}},\n  "pointCount": 64\n}',
            tests="""
pm.test('Status 200 (replay, not created)', () => pm.response.to.have.status(200));
pm.test('Same glyph id', () => pm.expect(pm.response.json().id).to.eql(pm.collectionVariables.get('glyph_id')));
"""),
    request("Same shape with a new mutation id is a duplicate", "POST",
            "/api/v1/chat/conversations/{{conversation_id}}/glyphs",
            body='{\n  "clientMutationId": "{{$guid}}",\n  "meaning": "copy",\n  "color": "#34D399",\n  "points": {{glyph_points}},\n  "pointCount": 64\n}',
            tests="expectProblem(409, 'GLYPH_DUPLICATE');"),
    request("Sync glyph dictionary", "GET", "/api/v1/chat/conversations/{{conversation_id}}/glyphs?afterRevision=0&limit=100",
            tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const page = pm.response.json();
const all = page.glyphs || page.items || [];
pm.test('Page lists glyphs', () => pm.expect(all).to.be.an('array'));
pm.test('Contains the new glyph', () => pm.expect(all.map(g => g.id)).to.include(pm.collectionVariables.get('glyph_id')));
"""),
    request("Get glyph by id", "GET", "/api/v1/chat/conversations/{{conversation_id}}/glyphs/{{glyph_id}}", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
pm.test('Same glyph', () => pm.expect(pm.response.json().id).to.eql(pm.collectionVariables.get('glyph_id')));
"""),
    request("Send glyph message", "POST", "/api/v1/chat/conversations/{{conversation_id}}/messages",
            prerequest="pm.collectionVariables.set('message_client_id', pm.variables.replaceIn('{{$guid}}'));",
            body='{\n  "type": "GLYPH",\n  "glyphIds": ["{{glyph_id}}"],\n  "clientId": "{{message_client_id}}"\n}',
            tests="""
pm.test('Status 201', () => pm.response.to.have.status(201));
const m = pm.response.json();
pm.test('Message is GLYPH from me', () => {
  pm.expect(m.type).to.eql('GLYPH');
  pm.expect(m.senderId).to.eql(pm.collectionVariables.get('my_public_id'));
});
pm.collectionVariables.set('message_id', m.id);
"""),
    request("Resending same clientId does not duplicate", "POST", "/api/v1/chat/conversations/{{conversation_id}}/messages",
            body='{\n  "type": "GLYPH",\n  "glyphIds": ["{{glyph_id}}"],\n  "clientId": "{{message_client_id}}"\n}',
            tests="""
pm.test('Accepted', () => pm.expect(pm.response.code).to.be.oneOf([200, 201]));
pm.test('Same message id', () => pm.expect(pm.response.json().id).to.eql(pm.collectionVariables.get('message_id')));
"""),
    request("Glyph message with unknown glyph is rejected", "POST", "/api/v1/chat/conversations/{{conversation_id}}/messages",
            body={"type": "GLYPH", "glyphIds": ["does-not-exist"]},
            tests="pm.test('Client error', () => pm.expect(pm.response.code).to.be.oneOf([400, 404, 409]));"),
    request("Text message follows server policy", "POST", "/api/v1/chat/conversations/{{conversation_id}}/messages",
            body={"type": "TEXT", "text": "hello from postman"},
            tests="""
// Mặc định CHAT_ALLOWED_TYPES=GLYPH nên TEXT bị tắt; nếu server bật TEXT thì phải tạo được tin.
if (pm.response.code === 201) {
  pm.test('Text message created', () => pm.expect(pm.response.json().type).to.eql('TEXT'));
} else {
  expectProblem(403, 'MESSAGE_TYPE_DISABLED');
}
"""),
    request("Message history", "GET", "/api/v1/chat/conversations/{{conversation_id}}/messages?limit=30", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const list = pm.response.json();
pm.test('History is an array', () => pm.expect(list).to.be.an('array'));
pm.test('Contains the sent message', () => pm.expect(list.map(m => m.id)).to.include(pm.collectionVariables.get('message_id')));
pm.test('Respects limit', () => pm.expect(list.length).to.be.at.most(30));
"""),
    request("Mark conversation read", "POST", "/api/v1/chat/conversations/{{conversation_id}}/read",
            tests="pm.test('Status 204', () => pm.response.to.have.status(204));"),
    request("Archive glyph", "DELETE", "/api/v1/chat/conversations/{{conversation_id}}/glyphs/{{glyph_id}}",
            tests="pm.test('Status 204', () => pm.response.to.have.status(204));"),
    request("Archived glyph cannot be sent", "POST", "/api/v1/chat/conversations/{{conversation_id}}/messages",
            body='{\n  "type": "GLYPH",\n  "glyphIds": ["{{glyph_id}}"]\n}',
            tests="expectProblem(409, 'GLYPH_NOT_ACTIVE');"),
    request("Unknown glyph returns 404", "GET", "/api/v1/chat/conversations/{{conversation_id}}/glyphs/does-not-exist",
            tests="expectProblem(404, 'GLYPH_NOT_FOUND');"),
    request("Unknown conversation returns 404", "GET", "/api/v1/chat/conversations/000000000000000000000000/messages",
            tests="expectProblem(404, 'NOT_FOUND');"),
])

# ---------------------------------------------------------------- 04 Billing
billing = folder("04 - billing-service", "Danh mục sản phẩm, ví, xác minh biên lai, thanh toán web và webhook.", [
    request("Product catalog", "GET", "/api/v1/billing/products", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const products = pm.response.json();
pm.test('Catalog is a non-empty array', () => pm.expect(products).to.be.an('array').that.is.not.empty);
pm.test('Every product has sku/type/item/quantity', () => products.forEach(p => {
  pm.expect(p.sku).to.be.a('string').and.not.empty;
  pm.expect(p.type).to.be.a('string');
  pm.expect(p.quantity).to.be.a('number');
}));
pm.test('SKUs are unique', () => pm.expect(new Set(products.map(p => p.sku)).size).to.eql(products.length));
const web = products.find(p => p.priceVnd != null || p.priceUsdCents != null);
const app = products.find(p => p.priceVnd == null && p.priceUsdCents == null);
pm.collectionVariables.set('web_sku', web ? web.sku : '');
pm.collectionVariables.set('store_only_sku', app ? app.sku : '');
pm.collectionVariables.set('any_sku', products[0].sku);
"""),
    request("My plan and wallet", "GET", "/api/v1/billing/me", tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
const b = pm.response.json();
pm.test('Has plan', () => pm.expect(b.plan).to.be.a('string'));
pm.test('Wallet is a map of non-negative balances', () => {
  pm.expect(b.wallet).to.be.an('object');
  Object.values(b.wallet).forEach(v => pm.expect(v).to.be.at.least(0));
});
"""),
    request("Verify rejects unknown store", "POST", "/api/v1/billing/purchases/verify",
            body={"store": "STEAM", "sku": "x", "token": "x"}, tests="expectProblem(400);"),
    request("Verify rejects blank token", "POST", "/api/v1/billing/purchases/verify",
            body='{\n  "store": "GOOGLE",\n  "sku": "{{any_sku}}",\n  "token": ""\n}', tests="expectProblem(400, 'VALIDATION_FAILED');"),
    request("Verify rejects unknown product", "POST", "/api/v1/billing/purchases/verify",
            body={"store": "GOOGLE", "sku": "no.such.sku", "token": "fake-token"},
            tests="expectProblem(400, 'UNKNOWN_PRODUCT');"),
    request("Verify fake receipt is not granted", "POST", "/api/v1/billing/purchases/verify",
            body='{\n  "store": "GOOGLE",\n  "sku": "{{any_sku}}",\n  "token": "fake-token-from-postman"\n}',
            tests="""
pm.test('Fake receipt never succeeds', () => pm.expect(pm.response.code).to.not.eql(200));
pm.test('Rejected as invalid or store unavailable', () => pm.expect(pm.response.json().code)
  .to.be.oneOf(['INVALID_RECEIPT', 'STORE_UNAVAILABLE', 'WEBHOOK_NOT_CONFIGURED', 'SKU_MISMATCH']));
"""),
    request("Checkout requires sku", "POST", "/api/v1/billing/checkout-sessions", body={"sku": ""},
            tests="expectProblem(400, 'VALIDATION_FAILED');"),
    request("Checkout rejects unknown sku", "POST", "/api/v1/billing/checkout-sessions", body={"sku": "no.such.sku"},
            tests="pm.test('Rejected', () => pm.expect(pm.response.code).to.be.oneOf([400, 503]));\n"
                  "if (pm.response.code === 400) pm.test('UNKNOWN_PRODUCT', () => pm.expect(pm.response.json().code).to.eql('UNKNOWN_PRODUCT'));"),
    request("Create web checkout session", "POST", "/api/v1/billing/checkout-sessions",
            body='{\n  "sku": "{{web_sku}}"\n}', tests="""
if (pm.response.code === 503) {
  expectProblem(503, 'PAYMENT_UNAVAILABLE');
} else {
  pm.test('Status 201', () => pm.response.to.have.status(201));
  const s = pm.response.json();
  pm.test('Has one-time checkout URL', () => pm.expect(s.url).to.match(/\\/pay\\/[^/]+$/));
  pm.test('Expires in the future', () => pm.expect(new Date(s.expiresAt).getTime()).to.be.above(Date.now()));
  pm.collectionVariables.set('checkout_token', s.url.split('/pay/')[1]);
}
"""),
    request("Checkout page opens without JWT", "GET", "/pay/{{checkout_token}}", auth=False, tests="""
pm.test('Status 200', () => pm.response.to.have.status(200));
pm.test('Returns an HTML page', () => pm.expect(pm.response.headers.get('Content-Type')).to.include('text/html'));
"""),
    request("Unknown checkout token returns 404", "GET", "/pay/not-a-real-token", auth=False,
            tests="pm.test('Status 404', () => pm.response.to.have.status(404));"),
    request("PayPal webhook without signature is rejected", "POST", "/webhooks/paypal", auth=False,
            body={"id": "WH-POSTMAN", "event_type": "PAYMENT.CAPTURE.COMPLETED"},
            tests="pm.test('Rejected (401 signature / 503 not configured)', () => pm.expect(pm.response.code).to.be.oneOf([401, 503]));"),
    request("payOS webhook with bad signature is rejected", "POST", "/webhooks/payos", auth=False,
            body={"code": "00", "data": {"orderCode": 1}, "signature": "bad"},
            tests="pm.test('Rejected (401 signature / 503 not configured)', () => pm.expect(pm.response.code).to.be.oneOf([401, 503]));"),
    request("Internal wallet API is not exposed", "GET", "/internal/wallet/{{my_public_id}}",
            tests="pm.test('Gateway does not route /internal', () => pm.expect(pm.response.code).to.be.oneOf([401, 403, 404]));"),
])

collection = {
    "info": {
        "_postman_id": str(uuid.uuid5(uuid.NAMESPACE_URL, "animal-locket-service-tests")),
        "name": "Animal Locket Service Tests (billing, chat, discovery, media)",
        "description": "Kiểm thử chức năng qua API Gateway cho billing, chat, discovery, media. "
                       "Sinh bởi postman/tools/build_service_tests.py. Hướng dẫn: postman/docs/05-service-tests.md.",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{access_token}}", "type": "string"}]},
    "variable": [{"key": "fixture_png_size", "value": str((ROOT / "fixtures/test-image.png").stat().st_size)}],
    "item": [setup, media, discovery, chat, billing],
}

OUT.write_text(json.dumps(collection, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {OUT.relative_to(ROOT.parent)} ({sum(len(f['item']) for f in collection['item'])} requests)")
