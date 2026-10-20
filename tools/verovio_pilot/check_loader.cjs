const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const verovio=require('../../output/verovio_pilot/assets/reader/verovio-toolkit-wasm.js');
const script=fs.readFileSync('output/verovio_pilot/assets/reader/reader.js','utf8');
verovio.module.onRuntimeInitialized=()=>{
  function environment(module){
    const messages=[],intervals=[],timeouts=[];
    const status={style:{},textContent:''};
    const context={verovio:{module,toolkit:verovio.toolkit},console,
      setInterval:fn=>(intervals.push(fn),intervals.length),clearInterval:()=>{},
      setTimeout:fn=>(timeouts.push(fn),timeouts.length),
      document:{getElementById:()=>status},
      Pilot:{postMessage:raw=>messages.push(JSON.parse(raw))},
      addEventListener:()=>{},innerWidth:411};
    context.window=context;
    vm.createContext(context);vm.runInContext(script,context);
    return {messages,intervals,timeouts};
  }
  const warm=environment({...verovio.module});
  assert.equal(warm.messages.filter(e=>e.type==='engine').length,1,'module initialized before reader script');
  const lateModule={};const late=environment(lateModule);
  assert.equal(late.messages.length,0);
  lateModule._vrvToolkit_constructor=verovio.module._vrvToolkit_constructor;
  lateModule.onRuntimeInitialized();
  late.intervals.forEach(fn=>fn());
  assert.equal(late.messages.filter(e=>e.type==='engine').length,1,'late callback and readiness poll initialize once');
  const missing=environment({});missing.timeouts.forEach(fn=>fn());
  assert.equal(missing.messages.filter(e=>e.type==='error').length,1,'missing runtime shows an error');
  console.log('PASS: warm start, delayed initialization, duplicate callback, missing runtime timeout');
};
