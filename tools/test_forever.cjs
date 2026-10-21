const fs = require('fs');
const path = require('path');
const assert = require('assert');
function dependency(name) {
  return require(require.resolve(name, {paths:[__dirname]}));
}
const {lua, lauxlib, lualib, to_luastring, to_jsstring} = dependency('fengari');
const parser = dependency('luaparse');
const root = path.resolve(__dirname, '..');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(source) {
  if (lauxlib.luaL_dostring(L, to_luastring(source)) !== lua.LUA_OK)
    throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
}
const test = fs.readFileSync(path.join(__dirname, 'test_forever.lua'), 'utf8').split('-- LOAD ADDON HERE');
run(test[0]);
const sources = fs.readFileSync(path.join(root, 'ForeverRecipeFinder/ForeverRecipeFinder.toc'), 'utf8')
  .replace(/^\uFEFF/, '').split(/\r?\n/).filter(s => s && !s.startsWith('#'));
for (const name of sources) {
  const file = path.join(root, 'ForeverRecipeFinder', name.replaceAll('\\', '/'));
  assert(fs.existsSync(file), 'Missing TOC file: ' + name);
  const src = fs.readFileSync(file, 'utf8');
  parser.parse(src, {luaVersion:'5.1'});
  run('assert(load([====[' + src + ']====]))("ForeverRecipeFinder", F)');
}
run(test[1]);
run(fs.readFileSync(path.join(__dirname, 'test_forever_storage.lua'), 'utf8'));
console.log('PASS: all TOC files parse as Lua 5.1 and execute in the mock WoW environment.');
