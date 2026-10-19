const puppeteer = require('puppeteer-core');
(async () => {
  const b = await puppeteer.launch({executablePath:'/usr/bin/google-chrome', headless:'new',
    args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader','--ignore-gpu-blocklist']});
  const p = await b.newPage();
  await p.setViewport({width:390,height:844,deviceScaleFactor:1,isMobile:false,hasTouch:false});
  p.on('console', m => console.log('CONSOLE', m.text().slice(0,200)));
  p.on('pageerror', e => console.log('PAGEERROR', e.message));
  await p.goto(process.argv[2], {waitUntil:'networkidle2', timeout:90000});
  await new Promise(r=>setTimeout(r, 2000));
  await p.mouse.click(195, 642);
  for (let k=0;k<4;k++){ await new Promise(r=>setTimeout(r, 1500)); await p.screenshot({path:`/tmp/c${k}.png`}); }
  await b.close();
})();
