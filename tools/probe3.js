const puppeteer = require('puppeteer-core');
(async () => {
  const b = await puppeteer.launch({executablePath:'/usr/bin/google-chrome', headless:'new',
    args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--ignore-gpu-blocklist']});
  const p = await b.newPage();
  await p.setViewport({width:390,height:844,deviceScaleFactor:1,isMobile:true,hasTouch:true});
  p.on('console', m => console.log('CONSOLE', m.text().slice(0,200)));
  await p.goto(process.argv[2], {waitUntil:'networkidle2', timeout:90000});
  for (let k=0;k<6;k++){
    await new Promise(r=>setTimeout(r, 1000));
    const r = await Promise.race([p.evaluate(()=>'alive '+performance.now()), new Promise(r=>setTimeout(()=>r('TIMEOUT'),3000))]);
    console.log(k, r);
  }
  const cdp = await p.target().createCDPSession();
  await cdp.send('Debugger.enable');
  cdp.on('Debugger.paused', ev => { console.log('PAUSED at', ev.callFrames.slice(0,8).map(f=>f.functionName+':'+f.location.lineNumber).join(' | ')); });
  await cdp.send('Debugger.pause');
  await new Promise(r=>setTimeout(r, 3000));
  process.exit(0);
})();
