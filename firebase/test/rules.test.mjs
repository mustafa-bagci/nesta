// Firestore güvenlik kuralı testleri (Firestore emülatörü üzerinde).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;
const now = 1791360000000;

const patient = (uid, midwifeId, status = 'pending') => ({
  uid,
  profile: { fullName: 'Test Gebe', birthDate: 0, dueDate: now },
  screening: null,
  consent: null,
  midwifeId,
  clearance: { status, decidedAt: null, decidedBy: null, note: null, disabledExercises: [] },
  createdAt: now,
  updatedAt: now,
});

const session = (id, patientId) => ({
  id, patientId, exerciseId: 'kedi_inek', startedAt: now, endedAt: now + 60000,
  endReason: 'completed', gestationalWeek: 24, reps: 0,
});

const alert = (id, patientId, midwifeId) => ({
  id, patientId, midwifeId, patientName: 'Test Gebe', type: 'symptom_before',
  message: 'Baş ağrısı', createdAt: now, urgent: false, acknowledgedAt: null,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nesta',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/m1'), { role: 'midwife', createdAt: now });
    await setDoc(doc(db, 'users/m2'), { role: 'midwife', createdAt: now });
    await setDoc(doc(db, 'users/p1'), { role: 'pregnant', createdAt: now });
    await setDoc(doc(db, 'users/p2'), { role: 'pregnant', createdAt: now });
    await setDoc(doc(db, 'midwives/m1'), {
      uid: 'm1', fullName: 'Zeynep Demir', title: 'Ebe', institution: 'Klinik', inviteCode: 'ABC234',
    });
    await setDoc(doc(db, 'inviteCodes/ABC234'), { midwifeId: 'm1' });
    await setDoc(doc(db, 'patients/p1'), patient('p1', 'm1', 'approved'));
    await setDoc(doc(db, 'patients/p2'), patient('p2', 'm2'));
    await setDoc(doc(db, 'patients/p1/sessions/s1'), session('s1', 'p1'));
    await setDoc(doc(db, 'alerts/a1'), alert('a1', 'p1', 'm1'));
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('kullanıcılar ve roller', () => {
  test('kişi kendi rol belgesini oluşturabilir', async () => {
    await assertSucceeds(setDoc(doc(as('yeni'), 'users/yeni'), { role: 'pregnant', createdAt: now }));
  });
  test('başkası adına rol oluşturulamaz', async () => {
    await assertFails(setDoc(doc(as('p1'), 'users/baska'), { role: 'midwife', createdAt: now }));
  });
  test('rol sonradan değiştirilemez', async () => {
    await assertFails(updateDoc(doc(as('p1'), 'users/p1'), { role: 'midwife' }));
  });
  test('geçersiz rol reddedilir', async () => {
    await assertFails(setDoc(doc(as('x'), 'users/x'), { role: 'admin', createdAt: now }));
  });
});

describe('davet kodları', () => {
  test('oturum açmış kullanıcı kodu sorgulayabilir', async () => {
    await assertSucceeds(getDoc(doc(as('p2'), 'inviteCodes/ABC234')));
  });
  test('oturumsuz kullanıcı sorgulayamaz', async () => {
    await assertFails(getDoc(doc(anon(), 'inviteCodes/ABC234')));
  });
  test('kodlar listelenemez', async () => {
    await assertFails(getDocs(collection(as('p1'), 'inviteCodes')));
  });
  test('gebe davet kodu oluşturamaz', async () => {
    await assertFails(setDoc(doc(as('p1'), 'inviteCodes/ZZZ999'), { midwifeId: 'p1' }));
  });
  test('ebe kendi kodunu oluşturabilir, başkası adına oluşturamaz', async () => {
    await assertSucceeds(setDoc(doc(as('m2'), 'inviteCodes/QWE234'), { midwifeId: 'm2' }));
    await assertFails(setDoc(doc(as('m2'), 'inviteCodes/QWE235'), { midwifeId: 'm1' }));
  });
});

describe('gebe kayıtları', () => {
  test('gebe kendi kaydını okur, başkasınınkini okuyamaz', async () => {
    await assertSucceeds(getDoc(doc(as('p1'), 'patients/p1')));
    await assertFails(getDoc(doc(as('p1'), 'patients/p2')));
  });
  test('ebe yalnızca kendisine bağlı gebeyi okur', async () => {
    await assertSucceeds(getDoc(doc(as('m1'), 'patients/p1')));
    await assertFails(getDoc(doc(as('m2'), 'patients/p1')));
  });
  test('ebe yalnızca kendi gebelerini listeleyebilir', async () => {
    await assertSucceeds(getDocs(query(collection(as('m1'), 'patients'), where('midwifeId', '==', 'm1'))));
    await assertFails(getDocs(collection(as('m1'), 'patients')));
  });
  test('gebe onaylı olarak kayıt oluşturamaz', async () => {
    await assertFails(setDoc(doc(as('p3'), 'patients/p3'), patient('p3', null, 'approved')));
    await assertSucceeds(setDoc(doc(as('p3'), 'patients/p3'), patient('p3', null, 'not_requested')));
  });
  test('gebe kendi onayını veremez', async () => {
    await assertFails(updateDoc(doc(as('p2'), 'patients/p2'), {
      clearance: { status: 'approved', decidedAt: now, decidedBy: 'p2', note: null, disabledExercises: [] },
    }));
  });
  test('gebe onayı koruyarak profilini güncelleyebilir', async () => {
    const p = patient('p1', 'm1', 'approved');
    p.profile.fullName = 'Yeni Ad';
    await assertSucceeds(setDoc(doc(as('p1'), 'patients/p1'), p));
  });
  test('gebe onayı koruyarak ebe değiştiremez', async () => {
    await assertFails(setDoc(doc(as('p1'), 'patients/p1'), patient('p1', 'm2', 'approved')));
    await assertSucceeds(setDoc(doc(as('p1'), 'patients/p1'), patient('p1', 'm2', 'pending')));
  });
  test('ebe onay verebilir', async () => {
    await assertSucceeds(updateDoc(doc(as('m2'), 'patients/p2'), {
      clearance: { status: 'approved', decidedAt: now, decidedBy: 'm2', note: 'Uygun', disabledExercises: ['kus_kopek'] },
      updatedAt: now,
    }));
  });
  test('ebe başka ebenin adına veya başka gebeye onay veremez', async () => {
    await assertFails(updateDoc(doc(as('m2'), 'patients/p2'), {
      clearance: { status: 'approved', decidedAt: now, decidedBy: 'm1', note: null, disabledExercises: [] },
    }));
    await assertFails(updateDoc(doc(as('m2'), 'patients/p1'), {
      clearance: { status: 'rejected', decidedAt: now, decidedBy: 'm2', note: null, disabledExercises: [] },
    }));
  });
  test('ebe gebenin profilini değiştiremez', async () => {
    await assertFails(updateDoc(doc(as('m1'), 'patients/p1'), { 'profile.fullName': 'Değişti' }));
  });
});

describe('seanslar', () => {
  test('gebe kendi seansını yazar, başkasına yazamaz', async () => {
    await assertSucceeds(setDoc(doc(as('p1'), 'patients/p1/sessions/s2'), session('s2', 'p1')));
    await assertFails(setDoc(doc(as('p1'), 'patients/p2/sessions/s3'), session('s3', 'p2')));
  });
  test('bağlı ebe seansları okur, diğer ebe okuyamaz', async () => {
    await assertSucceeds(getDocs(collection(as('m1'), 'patients/p1/sessions')));
    await assertFails(getDocs(collection(as('m2'), 'patients/p1/sessions')));
  });
  test('ebe seans yazamaz', async () => {
    await assertFails(setDoc(doc(as('m1'), 'patients/p1/sessions/s9'), session('s9', 'p1')));
  });
});

describe('uyarılar', () => {
  test('gebe kendi ebesine uyarı oluşturur, başka ebeye oluşturamaz', async () => {
    await assertSucceeds(setDoc(doc(as('p1'), 'alerts/a2'), alert('a2', 'p1', 'm1')));
    await assertFails(setDoc(doc(as('p1'), 'alerts/a3'), alert('a3', 'p1', 'm2')));
  });
  test('başkası adına uyarı oluşturulamaz', async () => {
    await assertFails(setDoc(doc(as('p2'), 'alerts/a4'), alert('a4', 'p1', 'm1')));
  });
  test('ebe yalnızca kendi uyarılarını görür', async () => {
    await assertSucceeds(getDocs(query(collection(as('m1'), 'alerts'), where('midwifeId', '==', 'm1'))));
    await assertFails(getDoc(doc(as('m2'), 'alerts/a1')));
    await assertFails(getDoc(doc(as('p1'), 'alerts/a1')));
  });
  test('ebe uyarıyı yalnızca "görüldü" olarak işaretleyebilir', async () => {
    await assertSucceeds(updateDoc(doc(as('m1'), 'alerts/a1'), { acknowledgedAt: now }));
    await assertFails(updateDoc(doc(as('m1'), 'alerts/a1'), { message: 'değişti' }));
  });
});
