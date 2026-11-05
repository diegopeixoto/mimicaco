#!/usr/bin/env bash
# Regera data/cartas.json a partir do cards.js do jogo web (pasta acima desta).
# Rode depois de editar as cartas: bash tools/atualizar_cartas.sh
set -e
cd "$(dirname "$0")/.."
node -e "
const {CATEGORIES,TWISTS,LEVELS}=require('../cards.js');
const out={levels:LEVELS,categories:CATEGORIES,twists:TWISTS,
 cat_order:['acao','objeto','gente','bicho','lugar','dificil'],
 cat_faces:['acao','objeto','gente','bicho','lugar','casa'],
 team_presets:[{name:'Equipe Rawzinho',color:'#5cc93a'},{name:'Equipe Toninho',color:'#e8453c'},{name:'Equipe Mochila',color:'#2f7bf5'},{name:'Equipe Sol',color:'#ffc21a'},{name:'Equipe Uva',color:'#a26bff'},{name:'Equipe Chiclete',color:'#ff6fb5'}]};
require('fs').writeFileSync('data/cartas.json',JSON.stringify(out,null,1));
let n=0;for(const c of Object.values(CATEGORIES))for(const l of Object.values(c.words))n+=l.length;
console.log('data/cartas.json atualizado:',n,'palavras');
"
