const BASE = (import.meta.env.VITE_API_BASE || 'http://localhost:8080/api').replace(/\/$/, '');

const authHeader = () => {
    const token = localStorage.getItem('token');
    return token ? { Authorization: `Bearer ${token}` } : {};
};

const handleResponse = async (res) => {
    const contentType = res.headers.get('content-type') || '';
    const isJson = contentType.includes('application/json');
    const requestId = res.headers.get('x-request-id') || null;

    if (res.status === 401) {
        localStorage.removeItem('token');
        localStorage.removeItem('role');
        window.location.href = '/login';
        throw new Error('Oturum süresi doldu');
    }
    if (!res.ok) {
        const error = isJson ? await res.json().catch(() => null) : null;
        const message = error?.message || error?.error || `İstek başarısız (HTTP ${res.status})`;
        const err = new Error(message);
        err.status = res.status;
        err.requestId = requestId;
        err.timestamp = new Date().toISOString();
        if (res.status === 429) {
            err.message = 'Çok fazla istek. Lütfen birazdan tekrar deneyin.';
        }
        throw err;
    }
    return isJson ? res.json() : res.text();
};

export const apiGet = (path) =>
    fetch(`${BASE}${path}`, { headers: authHeader() }).then(handleResponse);

export const apiPost = (path, body) =>
    fetch(`${BASE}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify(body)
    }).then(handleResponse);

export const apiPatch = (path, body) =>
    fetch(`${BASE}${path}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify(body)
    }).then(handleResponse);

export const apiDelete = (path) =>
    fetch(`${BASE}${path}`, { method: 'DELETE', headers: authHeader() }).then(handleResponse);

export const loginWithCredentials = async (username, password) => {
    const res = await fetch(`${BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
    });
    if (!res.ok) throw new Error('Geçersiz kullanıcı adı veya şifre');
    return res.json();
};
