const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(__dirname+'/../frontend/i18n.js','utf8').split('const translatedNodes')[0];
function context(locale='en-US',saved=null){const c=vm.createContext({navigator:{language:locale},localStorage:{getItem:()=>saved}});vm.runInContext(source,c);return c}
const c=context();
const t=text=>vm.runInContext(`translate(${JSON.stringify(text)},'en')`,c);
test('OS locale fallback and saved override',()=>{
 for(const [locale,want] of [['vi-VN','vi'],['vi','vi'],['en-US','en'],['fr-FR','en'],['','en']]) assert.equal(vm.runInContext('language',context(locale)),want);
 assert.equal(vm.runInContext('language',context('en-US','vi')),'vi');
 assert.equal(vm.runInContext('language',context('vi-VN','invalid')),'vi');
});
test('dynamic progress and errors retain values',()=>{
 assert.equal(t('Tải 375 thành phần từ nguồn đã ghim'),'Download 375 components from pinned sources');
 assert.equal(t('Còn khoảng 2 phút 12 giây'),'About 2 min 12 sec');
 assert.equal(t('Chưa hoàn tất — Ghi USB'),'Incomplete — Write USB');
 assert.equal(t('Lập kho gói: package_1.0.deb'),'Indexing packages: package_1.0.deb');
 assert.equal(t('USB đọc lại không khớp checksum; chưa thể dùng để cài'),'USB readback checksum mismatch; do not use it to install');
});
test('catalog translates in one pass and preserves Vietnamese source',()=>{
 const dictionary=vm.runInContext('english',c);
 for(const [vi,en] of Object.entries(dictionary)) {
  assert.equal(t(vi),en,vi);
  assert.equal(vm.runInContext(`translate(${JSON.stringify(vi)},'vi')`,c),vi);
 }
});
