const puppeteer = require('puppeteer-core');
(async () => {
  const b = await puppeteer.launch({executablePath:'/usr/bin/google-chrome', headless:'new',
    args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--ignore-gpu-blocklist']});
  const p = await b.newPage();
  await p.setViewport({width:390,height:844,deviceScaleFactor:1,isMobile:true,hasTouch:true});
  p.on('console', m => console.log('CONSOLE', m.type(), m.text().slice(0,300)));
  p.on('requestfailed', r => console.log('REQFAIL', r.url(), r.failure().errorText));
  p.on('response', r => { if (r.status()>=400) console.log('HTTP', r.status(), r.url()); });
  await p.goto(process.argv[2], {waitUntil:'networkidle2', timeout:90000});
  for (let k=0;k<8;k++){await new Promise(r=>setTimeout(r, 700)); await p.screenshot({path:'/tmp/pr'+k+'.png'});}
  console.log(await p.evaluate(() => document.body.innerHTML.slice(0,800)));
  console.log(await p.evaluate(() => { const c=document.createElement('canvas'); return !!(c.getContext('webgl2')||c.getContext('webgl')); }));
  await p.screenshot({path:'/tmp/probe.png'});
  await b.close();
})();
