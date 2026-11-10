import {readFileSync} from 'node:fs';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, query, where, Timestamp, serverTimestamp, deleteField} from 'firebase/firestore';
let env;
const device = '0123456789abcdef';
const date = () => new Date(Date.now()+8*3600000).toISOString().slice(0,10);
const auth = (uid) => env.authenticatedContext(uid,{email:`${uid}@cec.test`}).firestore();
const session = (extra={}) => ({facultyId:'teacher',classId:'class1',subject:'IT 101',roomId:'Room305',date:date(),openedAt:Timestamp.fromMillis(Date.now()-60000),closesAt:Timestamp.fromMillis(Date.now()+600000),status:'open',enrolledStudentIds:['alice'],...extra});
const attendance = (extra={}) => ({studentId:'alice',studentName:'Alice',facultyId:'teacher',classId:'class1',sessionId:'session1',subject:'IT 101',beaconId:'FindMoSer_Room305',roomId:'Room305',zoneName:'Room305',rssi:-60,dwellSeconds:15,deviceId:device,localTimestamp:Timestamp.now(),serverTimestamp:serverTimestamp(),date:date(),attendanceStatus:'present',...extra});
const admin = async (fn) => env.withSecurityRulesDisabled(ctx=>fn(ctx.firestore()));
const putAttendance = async () => admin(db=>setDoc(doc(db,'attendance/session1_alice'),attendance()));
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-findmoser',firestore:{host:'127.0.0.1',port:8088,rules:readFileSync('../firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{
 await env.clearFirestore();
 await admin(async db=>{
  const batch=writeBatch(db);
  batch.set(doc(db,'users/alice'),{displayName:'Alice',email:'alice@cec.test',role:'student',department:'BSIT',facultyApproved:false,deviceId:device});
  batch.set(doc(db,'users/bob'),{displayName:'Bob',email:'bob@cec.test',role:'student',department:'BSIT',facultyApproved:false,deviceId:'1123456789abcdef'});
  for(const id of ['teacher','otherteacher','unapproved']) batch.set(doc(db,`users/${id}`),{displayName:id,email:`${id}@cec.test`,role:'faculty',department:'BSIT',facultyApproved:id!='unapproved'});
  batch.set(doc(db,'users/adminx'),{displayName:'Admin',email:'admin@cec.test',role:'admin',department:'BSIT',facultyApproved:false});
  batch.set(doc(db,`device_bindings/${device}`),{uid:'alice',createdAt:Timestamp.now()});
  batch.set(doc(db,'users/teacher/class_schedule/class1'),{dayOfWeek:'Wednesday',startTime:'09:00',endTime:'10:00',roomName:'Room305',subject:'IT 101',studentIds:['alice']});
  batch.set(doc(db,'attendance_sessions/session1'),session());
  await batch.commit();
 });
});
test('enrolled bound student can submit a matching scan',async()=>{await assertSucceeds(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance()));});
test('student queries work only for own attendance',async()=>{
 await putAttendance(); const db=auth('alice');
 await assertSucceeds(getDocs(query(collection(db,'attendance'),where('studentId','==','alice'),where('date','==',date()))));
 await assertFails(getDocs(collection(db,'attendance')));
 await assertFails(getDoc(doc(auth('bob'),'attendance/session1_alice')));
});
test('missing attendance lookup is allowed for duplicate preflight',async()=>{await assertSucceeds(getDoc(doc(auth('alice'),'attendance/session1_alice')));});
test('faculty queries are constrained to own records',async()=>{
 await putAttendance();
 await assertSucceeds(getDocs(query(collection(auth('teacher'),'attendance'),where('facultyId','==','teacher'),where('sessionId','==','session1'))));
 await assertFails(getDocs(collection(auth('teacher'),'attendance')));
 await assertFails(getDoc(doc(auth('otherteacher'),'attendance/session1_alice')));
});
test('student session query must include enrollment',async()=>{
 await assertSucceeds(getDocs(query(collection(auth('alice'),'attendance_sessions'),where('enrolledStudentIds','array-contains','alice'),where('date','==',date()))));
 await assertFails(getDocs(collection(auth('alice'),'attendance_sessions')));
 await assertFails(getDoc(doc(auth('bob'),'attendance_sessions/session1')));
 await assertFails(getDoc(doc(auth('bob'),'attendance_sessions/session3late')));
});
test('a student who joined the class code late reads the open session',async()=>{
 // Faculty opened the session against an empty schedule roster after bob
 // had already enrolled; session2 carries the code bob's membership proves.
 await admin(async db=>{
  const batch=writeBatch(db);
  batch.set(doc(db,'users/teacher/class_schedule/class2'),{dayOfWeek:'Wednesday',startTime:'09:00',endTime:'10:00',roomName:'Room305',subject:'IT 102',studentIds:['alice']});
  batch.set(doc(db,'attendance_sessions/session2late'),session({classId:'class2',subject:'IT 102',joinCode:'ABC123',enrolledStudentIds:['eve']}));
  batch.set(doc(db,'class_codes/ABC123'),{facultyId:'teacher',classId:'class2',subject:'IT 102',roomName:'Room305',dayOfWeek:'Wednesday',startTime:'09:00',endTime:'10:00'});
  batch.set(doc(db,'class_codes/ABC123/members/bob'),{studentId:'bob',joinedAt:Timestamp.now()});
  await batch.commit();
 });
 await assertSucceeds(getDoc(doc(auth('bob'),'attendance_sessions/session2late')));
 await assertFails(getDoc(doc(auth('alice'),'attendance_sessions/session2late')));
 // Valid session must list joinCode; a malformed code is rejected.
 await assertSucceeds(setDoc(doc(auth('teacher'),'attendance_sessions/newsessioncode'),session({classId:'class2',subject:'IT 102',joinCode:'ZZZ999',openedAt:serverTimestamp()})));
 await assertFails(setDoc(doc(auth('teacher'),'attendance_sessions/badcode'),session({classId:'class2',subject:'IT 102',joinCode:'short',openedAt:serverTimestamp()})));
});
test('duplicates cannot overwrite original evidence',async()=>{
 const ref=doc(auth('alice'),'attendance/session1_alice'); await assertSucceeds(setDoc(ref,attendance()));
 await assertFails(setDoc(ref,attendance({rssi:-50})));
 await assertFails(deleteDoc(ref));
});
test('wrong room, weak signal, insufficient dwell and noninteger evidence fail',async()=>{
 for(const change of [{roomId:'Room306'},{beaconId:'FindMoSer_Room306'},{rssi:-71},{dwellSeconds:14},{dwellSeconds:15.5},{rssi:3}]) await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance(change)));
});
test('unbound or non-enrolled student cannot submit',async()=>{
 await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({deviceId:'1123456789abcdef'})));
 await assertFails(setDoc(doc(auth('bob'),'attendance/session1_bob'),attendance({studentId:'bob',studentName:'Bob',deviceId:'1123456789abcdef'})));
});
test('student cannot submit as another user or random document ID',async()=>{
 await assertFails(setDoc(doc(auth('bob'),'attendance/session1_alice'),attendance()));
 await assertFails(setDoc(doc(auth('alice'),'attendance/random'),attendance()));
});
test('offline scans syncing after close are accepted when evidence is inside the window',async()=>{
 await admin(db=>setDoc(doc(db,'attendance_sessions/session1'),session({status:'closed'})));
 await assertSucceeds(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance()));
});
test('evidence outside the window or past the 24h sync grace fails',async()=>{
 for(const change of [{},{closesAt:Timestamp.fromMillis(Date.now()-10000)}]){
  await admin(db=>setDoc(doc(db,'attendance_sessions/session1'),session({status:'closed',...change})));
  await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({localTimestamp:Timestamp.fromMillis(Date.now()-120000)})));
 }
 await admin(db=>setDoc(doc(db,'attendance_sessions/session1'),session({status:'closed'})));
 await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({localTimestamp:Timestamp.fromMillis(Date.now()+700000)})));
 await admin(db=>setDoc(doc(db,'attendance_sessions/session1'),session({status:'closed',openedAt:Timestamp.fromMillis(Date.now()-90000000),closesAt:Timestamp.fromMillis(Date.now()-86500000)})));
 await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({localTimestamp:Timestamp.fromMillis(Date.now()-89900000)})));
});
test('evidence at the exact window edges is half-open',async()=>{
 const openedAt=Date.now()-60000,closesAt=Date.now()+600000;
 await admin(db=>setDoc(doc(db,'attendance_sessions/session1'),session({status:'closed',openedAt:Timestamp.fromMillis(openedAt),closesAt:Timestamp.fromMillis(closesAt)})));
 await assertSucceeds(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({localTimestamp:Timestamp.fromMillis(openedAt)})));
 await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance({localTimestamp:Timestamp.fromMillis(closesAt)})));
});
test('quick scan, forged timestamp/status/name and extra fields fail',async()=>{
 for(const change of [{classId:'quick_scan'},{serverTimestamp:Timestamp.fromMillis(1)},{attendanceStatus:'excused'},{studentName:'Someone else'},{facultyId:'otherteacher'},{date:'2000-01-01'},{admin:true}]) await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance(change)));
});
test('anonymous clients cannot read or write attendance',async()=>{
 const db=env.unauthenticatedContext().firestore();
 await assertFails(getDoc(doc(db,'attendance/session1_alice')));
 await assertFails(setDoc(doc(db,'attendance/session1_alice'),attendance()));
});
test('roles, approval and bound device are immutable for clients',async()=>{
 for(const change of [{role:'faculty'},{facultyApproved:true},{deviceId:'1123456789abcdef'}]) await assertFails(updateDoc(doc(auth('alice'),'users/alice'),change));
 await assertSucceeds(updateDoc(doc(auth('alice'),'users/alice'),{displayName:'Alice New'}));
 await assertFails(updateDoc(doc(auth('unapproved'),'users/unapproved'),{facultyApproved:true}));
});
test('name-only edits work for legacy profiles with missing or empty department and null photo',async()=>{
 for (const legacy of [{}, {department:''}, {department:'BSIT',profilePhotoUrl:null}]) {
  await admin(db=>setDoc(doc(db,'users/alice'),{displayName:'Alice',email:'alice@cec.test',role:'student',facultyApproved:false,deviceId:device,...legacy}));
  await assertSucceeds(updateDoc(doc(auth('alice'),'users/alice'),{displayName:'Alice Corrected'}));
 }
});
test('profile edits still reject invalid changed fields and edits by another student',async()=>{
 const own=doc(auth('alice'),'users/alice');
 for (const change of [{displayName:''},{displayName:'x'.repeat(101)},{department:''},{department:null},{profilePhotoUrl:42}]) {
  await assertFails(updateDoc(own,change));
 }
 await assertFails(updateDoc(doc(auth('bob'),'users/alice'),{displayName:'Another student'}));
});
test('student registration requires atomic unique device binding',async()=>{
 const db=auth('newstudent'); const newDevice='2123456789abcdef';
 const profile={displayName:'New Student',email:'newstudent@cec.test',role:'student',department:'BSIT',facultyApproved:false,deviceId:newDevice,createdAt:serverTimestamp()};
 await assertFails(setDoc(doc(db,'users/newstudent'),profile));
 const batch=writeBatch(db);batch.set(doc(db,'users/newstudent'),profile);batch.set(doc(db,`device_bindings/${newDevice}`),{uid:'newstudent',createdAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
 await assertFails(setDoc(doc(db,`device_bindings/${device}`),{uid:'newstudent',createdAt:serverTimestamp()}));
 await assertFails(getDocs(collection(db,'device_bindings')));
});
test('faculty signup is a request and cannot approve itself',async()=>{
 const db=auth('newfaculty');const profile={displayName:'Faculty',email:'newfaculty@cec.test',role:'faculty',department:'BSIT',facultyApproved:false,createdAt:serverTimestamp()};
 await assertFails(setDoc(doc(db,'users/newfaculty'),{...profile,facultyApproved:true}));
 await assertSucceeds(setDoc(doc(db,'users/newfaculty'),profile));
 await assertFails(getDocs(collection(db,'users')));
});
test('only approved faculty can open a matching enrolled session',async()=>{
 await assertSucceeds(setDoc(doc(auth('teacher'),'attendance_sessions/newsession'),session({openedAt:serverTimestamp()})));
 await assertFails(setDoc(doc(auth('unapproved'),'attendance_sessions/newsession2'),session({facultyId:'unapproved',openedAt:serverTimestamp()})));
 for(const change of [{roomId:'WrongRoom'},{enrolledStudentIds:['bob']},{date:'2000-01-01'},{closesAt:Timestamp.fromMillis(Date.now()+5*3600000)}]) await assertFails(setDoc(doc(auth('teacher'),'attendance_sessions/invalid'),session({openedAt:serverTimestamp(),...change})));
});
test('only owning faculty may close and cannot rewrite session enrollment',async()=>{
 await assertFails(updateDoc(doc(auth('otherteacher'),'attendance_sessions/session1'),{status:'closed',closedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(auth('teacher'),'attendance_sessions/session1'),{enrolledStudentIds:['bob']}));
 await assertSucceeds(updateDoc(doc(auth('teacher'),'attendance_sessions/session1'),{status:'closed',closedAt:serverTimestamp()}));
});
test('faculty correction requires an immutable, matching audit in same batch',async()=>{
 await putAttendance();const db=auth('teacher');const record=doc(db,'attendance/session1_alice');
 await assertFails(updateDoc(record,{attendanceStatus:'late',lastCorrectionId:'a',correctedAt:serverTimestamp()}));
 const audit=doc(db,'attendance/session1_alice/corrections/a');const batch=writeBatch(db);
 batch.set(audit,{facultyId:'teacher',fromStatus:'present',toStatus:'late',reason:'Verified with class adviser.',at:serverTimestamp()});
 batch.update(record,{attendanceStatus:'late',lastCorrectionId:'a',correctedAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
 await assertFails(updateDoc(audit,{reason:'Changed history'}));
 await assertFails(deleteDoc(audit));
 await assertFails(updateDoc(record,{rssi:-50}));
});
test('short correction reason fails atomically',async()=>{
 await putAttendance();const db=auth('teacher');const batch=writeBatch(db);
 batch.set(doc(db,'attendance/session1_alice/corrections/a'),{facultyId:'teacher',fromStatus:'present',toStatus:'late',reason:'Oops',at:serverTimestamp()});
 batch.update(doc(db,'attendance/session1_alice'),{attendanceStatus:'late',lastCorrectionId:'a',correctedAt:serverTimestamp()});
 await assertFails(batch.commit());
});
test('device recovery is self-only, pending only and cannot rebind the account',async()=>{
 const db=auth('alice');const ref=doc(db,'device_change_requests/alice');const request={studentId:'alice',newDeviceId:'3123456789abcdef',reason:'My original phone is broken.',status:'pending',requestedAt:serverTimestamp()};
 await assertSucceeds(setDoc(ref,request));
 await assertFails(setDoc(ref,request));
 await assertFails(updateDoc(ref,{status:'approved'}));
 await assertFails(getDoc(doc(auth('bob'),'device_change_requests/alice')));
 await assertFails(updateDoc(doc(db,'users/alice'),{deviceId:request.newDeviceId}));
});
test('schedule CRUD supports enrollment and rejects non-owning roles',async()=>{
 const data={dayOfWeek:'Wednesday',startTime:'09:00',endTime:'10:00',roomName:'Room305',subject:'IT 101'};
 const ref=doc(auth('teacher'),'users/teacher/class_schedule/newclass');
 await assertSucceeds(setDoc(ref,data));
 await assertSucceeds(updateDoc(ref,{studentIds:['alice','bob']}));
 await assertFails(updateDoc(doc(auth('otherteacher'),'users/teacher/class_schedule/newclass'),{studentIds:[]}));
 await assertFails(setDoc(doc(auth('alice'),'users/alice/class_schedule/newclass'),data));
 await assertFails(updateDoc(ref,{endTime:'08:00'}));
 await assertSucceeds(deleteDoc(ref));
});
test('correction audit cannot be forged independently or reused',async()=>{
 await putAttendance();const db=auth('teacher');const audit={facultyId:'teacher',fromStatus:'present',toStatus:'late',reason:'Verified after class review.',at:serverTimestamp()};
 await assertFails(setDoc(doc(db,'attendance/session1_alice/corrections/lone'),audit));
 const other=auth('otherteacher');const batch=writeBatch(other);
 batch.set(doc(other,'attendance/session1_alice/corrections/wrong'),{...audit,facultyId:'otherteacher'});
 batch.update(doc(other,'attendance/session1_alice'),{attendanceStatus:'late',lastCorrectionId:'wrong',correctedAt:serverTimestamp()});
 await assertFails(batch.commit());
});
test('faculty can set consultation availability and sharing hours only on self',async()=>{
 await assertSucceeds(updateDoc(doc(auth('teacher'),'users/teacher'),{availability:'available'}));
 await assertSucceeds(updateDoc(doc(auth('teacher'),'users/teacher'),{workStartTime:'08:00',workEndTime:'17:00'}));
 await assertFails(updateDoc(doc(auth('teacher'),'users/teacher'),{availability:'napping'}));
 await assertFails(updateDoc(doc(auth('teacher'),'users/teacher'),{workStartTime:'8am'}));
 await assertFails(updateDoc(doc(auth('alice'),'users/alice'),{availability:'available'}));
 await assertFails(updateDoc(doc(auth('alice'),'users/teacher'),{availability:'available'}));
});
test('class codes join students to their own membership only',async()=>{
 const code={facultyId:'teacher',classId:'class1',subject:'IT 101',roomName:'Room305',dayOfWeek:'Wednesday',startTime:'09:00',endTime:'10:00'};
 await assertSucceeds(setDoc(doc(auth('teacher'),'class_codes/ABC123'),code));
 await assertSucceeds(getDoc(doc(auth('alice'),'class_codes/ABC123')));
 await assertFails(getDocs(collection(auth('alice'),'class_codes')));
 await assertFails(setDoc(doc(auth('otherteacher'),'class_codes/ABC123'),{...code,facultyId:'otherteacher'}));
 const member={studentId:'alice',joinedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(auth('alice'),'class_codes/ABC123/members/alice'),member));
 await assertFails(setDoc(doc(auth('bob'),'class_codes/ABC123/members/alice'),{...member,studentId:'bob'}));
 await assertFails(getDocs(collection(auth('bob'),'class_codes/ABC123/members')));
 await assertSucceeds(getDocs(collection(auth('teacher'),'class_codes/ABC123/members')));
});
test('faculty presence is a sanitized student-readable projection',async()=>{
 const presence={displayName:'teacher',department:'BSIT',availability:'available',zoneName:'Room305',currentRoom:'Room305',beaconId:'FindMoSer_Room305',updatedAt:Timestamp.now(),isSharing:true,workStartTime:'08:00',workEndTime:'17:00'};
 await assertSucceeds(setDoc(doc(auth('teacher'),'faculty_presence/teacher'),presence));
 await assertSucceeds(getDoc(doc(auth('alice'),'faculty_presence/teacher')));
 await assertSucceeds(getDocs(collection(auth('alice'),'faculty_presence')));
 await assertFails(setDoc(doc(auth('otherteacher'),'faculty_presence/teacher'),presence));
 await assertFails(setDoc(doc(auth('alice'),'faculty_presence/alice'),presence));
 await assertFails(setDoc(doc(auth('teacher'),'faculty_presence/teacher'),{...presence,email:'teacher@cec.test'}));
 await assertSucceeds(deleteDoc(doc(auth('teacher'),'faculty_presence/teacher')));
});
test('raw locations stay owner-only for approved faculty',async()=>{
 const location={isVisible:true,isWithinCampus:true,currentRoom:'Room305',beaconId:'FindMoSer_Room305',zoneName:'Room305',timestamp:Timestamp.now()};
 await assertSucceeds(setDoc(doc(auth('teacher'),'locations/teacher'),location));
 await assertSucceeds(getDoc(doc(auth('teacher'),'locations/teacher')));
 await assertFails(getDoc(doc(auth('alice'),'locations/teacher')));
 await assertFails(getDocs(collection(auth('alice'),'locations')));
 await assertFails(setDoc(doc(auth('otherteacher'),'locations/teacher'),location));
});
test('faculty marks only closed sessions for enrolled students without a receipt',async()=>{
  const db=auth('teacher');
  const mark={facultyId:'teacher',studentId:'alice',sessionId:'session1',subject:'IT 101',attendanceStatus:'absent',studentName:'Alice',reason:'Student never arrived during the pilot window.',markedAt:serverTimestamp()};
  await assertFails(setDoc(doc(db,'attendance_marks/session1_alice'),mark));
  await admin(d=>updateDoc(doc(d,'attendance_sessions/session1'),{status:'closed',closedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db,'attendance_marks/other_alice'),{...mark,facultyId:'otherteacher',studentId:'alice',sessionId:'session1'}));
  await assertFails(setDoc(doc(db,'attendance_marks/present_alice'),{...mark,sessionId:'session1',attendanceStatus:'present'}));
  await assertFails(setDoc(doc(db,'attendance_marks/shortreason_alice'),{...mark,sessionId:'session1',reason:'short'}));
  await assertFails(setDoc(doc(db,'attendance_marks/extra_alice'),{...mark,sessionId:'session1',adminNote:'extra'}));
  await assertSucceeds(setDoc(doc(db,'attendance_marks/session1_alice'),mark));
});
test('faculty cannot mark a student with a real receipt or an unenrolled student',async()=>{
  const db=auth('teacher');
  await putAttendance();
  await admin(d=>updateDoc(doc(d,'attendance_sessions/session1'),{status:'closed',closedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db,'attendance_marks/session1_alice'),{facultyId:'teacher',studentId:'alice',sessionId:'session1',subject:'IT 101',attendanceStatus:'excused',studentName:'Alice',reason:'Excused: official activity approved by the campus.',markedAt:serverTimestamp()}));
  await assertFails(setDoc(db?doc(db,'attendance_marks/session1_bob'):null,{facultyId:'teacher',studentId:'bob',sessionId:'session1',subject:'IT 101',attendanceStatus:'absent',studentName:'Bob',reason:'Student never arrived during the pilot window.',markedAt:serverTimestamp()}));
});
test('students can read only their own mark and no one may edit marks',async()=>{
  const fixed=auth('teacher');
  await admin(d=>updateDoc(doc(d,'attendance_sessions/session1'),{status:'closed',closedAt:serverTimestamp()}));
  const mark={facultyId:'teacher',studentId:'alice',sessionId:'session1',subject:'IT 101',attendanceStatus:'excused',studentName:'Alice',reason:'Excused: official science fair participation.',markedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(auth('teacher'),'attendance_marks/session1_alice'),mark));
  await assertSucceeds(getDoc(doc(auth('alice'),'attendance_marks/session1_alice')));
  await assertFails(getDoc(doc(auth('bob'),'attendance_marks/session1_alice')));
  await assertFails(getDocs(query(collection(auth('bob'),'attendance_marks'),where('studentId','==','alice'))));
  await assertSucceeds(getDocs(query(collection(auth('alice'),'attendance_marks'),where('studentId','==','alice'))));
  await assertFails(updateDoc(doc(fixed,'attendance_marks/session1_alice'),{reason:'Rewriting history'}));
  await assertFails(deleteDoc(doc(fixed,'attendance_marks/session1_alice')));
});
test('admin adjudication of device change requests is audited and atomic',async()=>{
  const studentCtx=auth('alice');
  await assertSucceeds(setDoc(doc(studentCtx,'device_change_requests/alice'),{studentId:'alice',newDeviceId:'3123456789abcdef',reason:'My original phone was lost at the fest.',status:'pending',requestedAt:serverTimestamp()}));
  const adm=auth('adminx');
  await assertFails(updateDoc(doc(adm,'device_change_requests/alice'),{status:'rejected'}));
  const adm2=env.authenticatedContext('adminx',{email:'adminx@cec.test'}).firestore();
  const nb='3123456789abcdef';
  const batch=writeBatch(adm2);
  batch.update(doc(adm2,'users/alice'),{deviceId:nb});
  batch.update(doc(adm2,'device_change_requests/alice'),{status:'approved',decidedAt:serverTimestamp(),decidedBy:'adminx',previousDeviceId:device});
  batch.set(doc(adm2,`device_bindings/${nb}`),{uid:'alice',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(adm2,'users/alice'),{deviceId:'4123456789abcdef'}));
  await assertFails(updateDoc(doc(studentCtx,'users/alice'),{facultyApproved:true}));
});
test('admin soft-deactivation only touches students and is reversible',async()=>{
  const adm=env.authenticatedContext('adminx',{email:'adminx@cec.test'}).firestore();
  await assertFails(updateDoc(doc(auth('alice'),'users/alice'),{deactivated:true}));
  await assertSucceeds(updateDoc(doc(adm,'users/alice'),{deactivated:true}));
  await assertFails(updateDoc(doc(adm,'users/alice'),{deactivated:'yes'}));
  await assertFails(updateDoc(doc(adm,'users/adminx'),{deactivated:true}));
  await assertFails(updateDoc(doc(adm,'users/teacher'),{deactivated:true}));
  await assertSucceeds(updateDoc(doc(adm,'users/alice'),{deactivated:false}));
});
test('a deactivated student cannot submit scans or file device requests',async()=>{
  await assertSucceeds(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance()));
  await admin(async db=>{await setDoc(doc(db,'users/alice'),{deactivated:true},{merge:true});});
  await admin(async db=>{await deleteDoc(doc(db,'attendance/session1_alice'));});
  await assertFails(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance()));
  await assertFails(setDoc(doc(auth('alice'),'device_change_requests/alice'),{studentId:'alice',newDeviceId:'3123456789abcdef',reason:'My original phone was lost at the fest.',status:'pending',requestedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('adminx',{email:'adminx@cec.test'}).firestore(),'users/alice'),{deactivated:false}));
  await assertSucceeds(setDoc(doc(auth('alice'),'attendance/session1_alice'),attendance()));
});
test('admin force-unbind is atomic across profile and ownership row',async()=>{
  const adm=env.authenticatedContext('adminx',{email:'adminx@cec.test'}).firestore();
  await assertFails(deleteDoc(doc(auth('alice'),`device_bindings/${device}`)));
  const bindingOnly=writeBatch(adm);
  bindingOnly.delete(doc(adm,`device_bindings/${device}`));
  await assertFails(bindingOnly.commit());
  const unbind=writeBatch(adm);
  unbind.update(doc(adm,'users/alice'),{deviceId:deleteField()});
  unbind.delete(doc(adm,`device_bindings/${device}`));
  await assertSucceeds(unbind.commit());
});
