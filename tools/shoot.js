const puppeteer = require('puppeteer-core');
const [url, outdir, secs, every] = [process.argv[2], process.argv[3], +process.argv[4]||150, +process.argv[5]||5];
(async () => {
  const b = await puppeteer.launch({executablePath:'/usr/bin/google-chrome', headless:'new',
    args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--ignore-gpu-blocklist']});
  const p = await b.newPage();
  await p.setViewport({width:390,height:844,deviceScaleFactor:1,isMobile:true,hasTouch:true});
  if (process.env.UA) await p.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1');
  p.on('console', m => { console.log('CONSOLE', m.type(), m.text().slice(0,300)); });
  p.on('pageerror', e => console.log('PAGEERROR', e.message));
  await p.goto(url, {waitUntil:'networkidle2', timeout:90000});
  const t0 = Date.now();
  let i = 0;
  while ((Date.now()-t0)/1000 < secs) {
    await new Promise(r=>setTimeout(r, every*1000));
    const f = `${outdir}/t${String(Math.round((Date.now()-t0)/1000)).padStart(3,'0')}.png`;
    await p.screenshot({path:f}); i++;
  }
  console.log('done', i);
  await b.close();
})().catch(e=>{console.log('FATAL', e.message); process.exit(1);});
