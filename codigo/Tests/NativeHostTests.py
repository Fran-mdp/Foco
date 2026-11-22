"""Exercises the real length-prefixed native protocol against a temporary store."""
import json,os,struct,subprocess,tempfile,time,uuid,select,sys
binary=sys.argv[1]
origin='chrome-extension://ffnpgijgkijehlmgedmniefkmodlnmgf/'
def send(p,obj):
 data=json.dumps(obj).encode();p.stdin.write(struct.pack('<I',len(data))+data);p.stdin.flush()
def recv(p):
 assert select.select([p.stdout],[],[],8)[0], 'Native host did not respond'
 size=struct.unpack('<I',p.stdout.read(4))[0];return json.loads(p.stdout.read(size))
with tempfile.TemporaryDirectory(prefix='FocoProtocol-') as directory:
 env={**os.environ,'FOCO_TEST_DIRECTORY':directory}
 denied=subprocess.run([binary,'chrome-extension://invalid/'],env=env,capture_output=True)
 assert denied.returncode==1 and not denied.stdout
 with subprocess.Popen([binary,origin],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE) as p:
  token=str(uuid.uuid4());send(p,{'op':'hello','profile':token});first=recv(p)
  assert first['session'] is None
  send(p,{'op':'ack','profile':token,'appliedID':''})
  deadline=time.time()+5
  while not os.path.exists(directory+'/state.json') or json.load(open(directory+'/state.json')).get('ownerProfile')!=token:
   assert time.time()<deadline
   time.sleep(.05)
  state=json.load(open(directory+'/state.json'));assert state['bridgeSeen']>time.time()-5
  p.stdin.close();assert p.wait(timeout=5)==0
 print('PASS native messaging: rejected unknown origin, framed JSON response, bound Chrome profile, heartbeat, clean disconnect')

# Reject untrusted framing and unsupported operations without touching user data.
with tempfile.TemporaryDirectory(prefix='FocoProtocolInvalid-') as directory:
 env={**os.environ,'FOCO_TEST_DIRECTORY':directory}
 invalid=[(struct.pack('<I',65537),2),
          (struct.pack('<I',1)+b'{',3),
          (lambda data: struct.pack('<I',len(data))+data)(json.dumps({'op':'run','profile':str(uuid.uuid4())}).encode())]
 for case in invalid:
  if isinstance(case,tuple):packet,expected=case
  else:packet,expected=case,3
  p=subprocess.Popen([binary,origin],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
  try:
   p.stdin.write(packet);p.stdin.flush()
   assert p.wait(timeout=5)==expected
  finally:
   if p.poll() is None:p.terminate();p.wait()
   p.stdin.close();p.stdout.close()
 print('PASS native messaging: oversized frames, malformed JSON and unsupported operations rejected')

# Task titles and identifiers must stay out of Chrome's native-message payload.
with tempfile.TemporaryDirectory(prefix='FocoProtocolTasks-') as directory:
 env={**os.environ,'FOCO_TEST_DIRECTORY':directory}
 token=str(uuid.uuid4());task_id=str(uuid.uuid4());goal_id=str(uuid.uuid4());now=time.time()
 state={'records':[],'bridgeSeen':now,'appliedID':'','revision':1,'ownerProfile':token,
        'goals':[{'id':goal_id,'title':'Private goal fixture','createdAt':now,'outcome':'partial','resultNote':'Private result fixture'}],
        'tasks':[{'id':task_id,'title':'Private task fixture','plannedFor':now,'createdAt':now}],
        'session':{'id':str(uuid.uuid4()),'startedAt':now,'firm':False,'taskID':task_id,'goalID':goal_id,'sites':[],'applications':[]}}
 with open(directory+'/state.json','w') as target:json.dump(state,target)
 with subprocess.Popen([binary,origin],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE) as p:
  send(p,{'op':'hello','profile':token});message=recv(p)
  assert 'taskID' not in message['session'] and 'tasks' not in message
  assert 'Private task fixture' not in json.dumps(message)
  assert 'goalID' not in message['session'] and 'goals' not in message
  assert 'Private goal fixture' not in json.dumps(message) and goal_id not in json.dumps(message)
  assert 'Private result fixture' not in json.dumps(message)
  p.stdin.close();assert p.wait(timeout=5)==0
 print('PASS native task/goal privacy: no titles, results or identifiers transmitted to Chrome')
