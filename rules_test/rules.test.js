// Security-rules tests. Run: firebase emulators:exec --only firestore "npm test"
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, collection, addDoc,
  getDocs, query, where,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'rules-test',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

// Seed data bypassing rules.
async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}
const profile = (uid, role) => seed((d) => setDoc(doc(d, 'profiles', uid), { name: uid, role, email: `${uid}@x.com` }));

// ---------- profiles & first-admin claim ----------
test('anonymous users cannot read anything', async () => {
  await profile('a', 'student');
  await assertFails(getDoc(doc(anon(), 'profiles', 'a')));
});

test('a user can create their own student profile, not someone else\'s', async () => {
  await assertSucceeds(setDoc(doc(db('u1'), 'profiles', 'u1'), { name: 'A', role: 'student' }));
  await assertFails(setDoc(doc(db('u1'), 'profiles', 'u2'), { name: 'B', role: 'student' }));
});

test('nobody can self-assign teacher or admin directly', async () => {
  await assertFails(setDoc(doc(db('u1'), 'profiles', 'u1'), { name: 'A', role: 'teacher' }));
  await assertFails(setDoc(doc(db('u1'), 'profiles', 'u1'), { name: 'A', role: 'admin' }));
});

test('first user can claim admin via the batch (profile + meta/admin)', async () => {
  const d = db('u1');
  const b = writeBatch(d);
  b.set(doc(d, 'meta', 'admin'), { uid: 'u1' });
  b.set(doc(d, 'profiles', 'u1'), { name: 'A', role: 'admin' });
  await assertSucceeds(b.commit());
});

test('second user cannot claim admin once it is taken', async () => {
  const d1 = db('u1');
  const b1 = writeBatch(d1);
  b1.set(doc(d1, 'meta', 'admin'), { uid: 'u1' });
  b1.set(doc(d1, 'profiles', 'u1'), { name: 'A', role: 'admin' });
  await b1.commit();

  const d2 = db('u2');
  const b2 = writeBatch(d2);
  b2.set(doc(d2, 'meta', 'admin'), { uid: 'u2' });
  b2.set(doc(d2, 'profiles', 'u2'), { name: 'B', role: 'admin' });
  await assertFails(b2.commit());
  await assertFails(setDoc(doc(d2, 'profiles', 'u2'), { name: 'B', role: 'admin' }));
});

test('cannot claim admin for a different uid in meta', async () => {
  const d = db('u1');
  const b = writeBatch(d);
  b.set(doc(d, 'meta', 'admin'), { uid: 'someone-else' });
  b.set(doc(d, 'profiles', 'u1'), { name: 'A', role: 'admin' });
  await assertFails(b.commit());
});

test('meta/admin is immutable', async () => {
  await seed((d) => setDoc(doc(d, 'meta', 'admin'), { uid: 'u1' }));
  await assertFails(updateDoc(doc(db('u1'), 'meta', 'admin'), { uid: 'u2' }));
  await assertFails(deleteDoc(doc(db('u1'), 'meta', 'admin')));
});

test('users cannot change their own role; admins can change others', async () => {
  await profile('s', 'student');
  await profile('boss', 'admin');
  await assertFails(updateDoc(doc(db('s'), 'profiles', 's'), { role: 'admin' }));
  await assertSucceeds(updateDoc(doc(db('s'), 'profiles', 's'), { name: 'New name' }));
  await assertSucceeds(updateDoc(doc(db('boss'), 'profiles', 's'), { role: 'teacher' }));
});

test('teachers cannot change roles', async () => {
  await profile('t', 'teacher');
  await profile('s', 'student');
  await assertFails(updateDoc(doc(db('t'), 'profiles', 's'), { role: 'teacher' }));
});

// ---------- courses ----------
const course = (instructorId, extra = {}) => ({
  title: 'C', description: 'd', instructor: 'X', instructorId, lessons: [], published: true, ...extra,
});

test('any signed-in user can read courses', async () => {
  await profile('s', 'student');
  await seed((d) => setDoc(doc(d, 'courses', 'c1'), course('t')));
  await assertSucceeds(getDoc(doc(db('s'), 'courses', 'c1')));
});

test('students cannot create, edit or delete courses', async () => {
  await profile('s', 'student');
  await seed((d) => setDoc(doc(d, 'courses', 'c1'), course('s')));
  await assertFails(setDoc(doc(db('s'), 'courses', 'new'), course('s')));
  await assertFails(updateDoc(doc(db('s'), 'courses', 'c1'), { title: 'hack' }));
  await assertFails(deleteDoc(doc(db('s'), 'courses', 'c1')));
});

test('teacher can create a course only as themselves', async () => {
  await profile('t', 'teacher');
  await assertSucceeds(setDoc(doc(db('t'), 'courses', 'c1'), course('t')));
  await assertFails(setDoc(doc(db('t'), 'courses', 'c2'), course('other')));
});

test('teacher edits/deletes only their own courses and cannot reassign ownership', async () => {
  await profile('t', 'teacher');
  await seed(async (d) => {
    await setDoc(doc(d, 'courses', 'mine'), course('t'));
    await setDoc(doc(d, 'courses', 'theirs'), course('other'));
  });
  await assertSucceeds(updateDoc(doc(db('t'), 'courses', 'mine'), { title: 'ok' }));
  await assertFails(updateDoc(doc(db('t'), 'courses', 'mine'), { instructorId: 'other' }));
  await assertFails(updateDoc(doc(db('t'), 'courses', 'theirs'), { title: 'hack' }));
  await assertFails(deleteDoc(doc(db('t'), 'courses', 'theirs')));
  await assertSucceeds(deleteDoc(doc(db('t'), 'courses', 'mine')));
});

test('admin can edit and delete any course', async () => {
  await profile('boss', 'admin');
  await seed((d) => setDoc(doc(d, 'courses', 'c1'), course('t')));
  await assertSucceeds(updateDoc(doc(db('boss'), 'courses', 'c1'), { title: 'edited' }));
  await assertSucceeds(deleteDoc(doc(db('boss'), 'courses', 'c1')));
});

test('a user without a profile cannot manage courses', async () => {
  await assertFails(setDoc(doc(db('ghost'), 'courses', 'c1'), course('ghost')));
});

// ---------- progress ----------
test('progress is private to its owner', async () => {
  await assertSucceeds(setDoc(doc(db('a'), 'users', 'a'), { done: ['l1'] }));
  await assertFails(getDoc(doc(db('b'), 'users', 'a')));
  await assertFails(setDoc(doc(db('b'), 'users', 'a'), { done: [] }));
});

// ---------- chats ----------
const chatBody = (a, b) => ({ participants: [a, b].sort(), names: { [a]: a, [b]: b } });

test('participants can create their chat with the correct id', async () => {
  await assertSucceeds(setDoc(doc(db('a'), 'chats', 'a_b'), chatBody('a', 'b')));
});

test('cannot create a chat you are not part of or with a mismatched id', async () => {
  await assertFails(setDoc(doc(db('c'), 'chats', 'a_b'), chatBody('a', 'b')));
  await assertFails(setDoc(doc(db('a'), 'chats', 'wrong_id'), chatBody('a', 'b')));
});

test('only participants can read a chat or its messages', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'chats', 'a_b'), chatBody('a', 'b'));
    await addDoc(collection(d, 'chats', 'a_b', 'messages'), { senderId: 'a', text: 'hi' });
  });
  await assertSucceeds(getDoc(doc(db('b'), 'chats', 'a_b')));
  await assertSucceeds(getDocs(collection(db('b'), 'chats', 'a_b', 'messages')));
  await assertFails(getDoc(doc(db('c'), 'chats', 'a_b')));
  await assertFails(getDocs(collection(db('c'), 'chats', 'a_b', 'messages')));
});

test('chat list query only returns my chats', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'chats', 'a_b'), chatBody('a', 'b'));
    await setDoc(doc(d, 'chats', 'c_d'), chatBody('c', 'd'));
  });
  await assertSucceeds(getDocs(query(collection(db('a'), 'chats'), where('participants', 'array-contains', 'a'))));
  await assertFails(getDocs(collection(db('a'), 'chats')));
});

test('sending: must be a participant, sender must be you, text must be valid', async () => {
  await seed((d) => setDoc(doc(d, 'chats', 'a_b'), chatBody('a', 'b')));
  const msgs = (uid) => collection(db(uid), 'chats', 'a_b', 'messages');
  await assertSucceeds(addDoc(msgs('a'), { senderId: 'a', text: 'hello' }));
  await assertFails(addDoc(msgs('a'), { senderId: 'b', text: 'spoofed' }));
  await assertFails(addDoc(msgs('c'), { senderId: 'c', text: 'intruder' }));
  await assertFails(addDoc(msgs('a'), { senderId: 'a', text: '' }));
  await assertFails(addDoc(msgs('a'), { senderId: 'a', text: 'x'.repeat(2001) }));
});

test('participants can update chat metadata but not the participant list', async () => {
  await seed((d) => setDoc(doc(d, 'chats', 'a_b'), chatBody('a', 'b')));
  await assertSucceeds(updateDoc(doc(db('a'), 'chats', 'a_b'), { lastMessage: 'hi', 'unread.b': true }));
  await assertFails(updateDoc(doc(db('a'), 'chats', 'a_b'), { participants: ['a', 'c'] }));
  await assertFails(updateDoc(doc(db('c'), 'chats', 'a_b'), { lastMessage: 'hack' }));
});
