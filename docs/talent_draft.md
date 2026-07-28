```js

let talent = Talent(player, "flash")
if(talent.is_skill){
    talentBTN.bind(talent)
}
```

```js
class Talent{
    Talent(chr, talent_name){
        return talent_rig[talent_name](chr)
    }
}
```

```js
let talent_rig = {
    "flash": (c)=>{
        let chr = c
        if(!chr.has(can_mov)){
            chr.can_mov = true
        }
        return ()=>{
            if(chr.can_mov){
                chr.x += chr.dir * 60
            }
        }
    }
}
```