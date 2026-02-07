import http from 'k6/http'
import { sleep } from 'k6'
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js'

export function createUser() {
    const credentials = {
        name: randomString(5, 'abcdefgh'),
        email: randomString(10, 'abcdefghijklmnopqrstuvwxyz0123456789') + '@k6.com',
        password: randomString(10),
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/register',
        JSON.stringify(credentials),
        { headers: { 'Content-Type': 'application/json' } }
    )
    sleep(1)
    const json = res.json()
    if (!json || !json.data || !json.data.id) {
        console.warn(`[createUser] Unexpected response: status=${res.status}`)
        console.warn(`[createUser] Body: ${res.body}`)
    }
    return { credentials, user_id: json?.data?.id }
}

export function loginUser(email, password) {
    const payload = { email, password }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/users/login',
        JSON.stringify(payload),
        { headers: { 'Content-Type': 'application/json' } }
    )
    sleep(1)
    const json = res.json()
    if (!json || !json.data || !json.data.token) {
        console.warn(`[loginUser] Unexpected response: status=${res.status}`)
        console.warn(`[loginUser] Body: ${res.body}`)
    }
    return json?.data?.token
}

export function createUserAndLogin() {
    const { credentials, user_id } = createUser()
    const token = loginUser(credentials.email, credentials.password)
    return { credentials, user_id, token }
}

export function createNote(token) {
    const note = {
        title: randomString(5) + randomString(4),
        description: randomString(5) + randomString(4) + randomString(5),
        category: randomItem(['Home', 'Work', 'Personal'])
    }
    let res = http.post(
        'https://practice.expandtesting.com/notes/api/notes',
        JSON.stringify(note),
        { headers: { 'X-Auth-Token': token, 'Content-Type': 'application/json' } }
    )
    sleep(1)
    const json = res.json()
    if (!json || !json.data || !json.data.id) {
        console.warn(`[createNote] Unexpected response: status=${res.status}`)
        console.warn(`[createNote] Body: ${res.body}`)
    }
    return { note, note_id: json?.data?.id, created_at: json?.data?.created_at, updated_at: json?.data?.updated_at }
}

export function deleteAccount(token) {
    let res = http.del(
        'https://practice.expandtesting.com/notes/api/users/delete-account',
        null,
        { headers: { 'X-Auth-Token': token, 'Content-Type': 'application/json' } }
    )
    sleep(1)
    return res
}
