;; The bumblebee model uses days as unit of time, and simulates a colony year-round (270 days; queens overwinter solo and start a new colony next spring)
;; 0.01 day is the smallest time unit used (== tick): 1 day == 100 ticks

globals
[
  days                       ;; day counter
  W-dom-center               ;; average dominance of workers in the nest center
  W-dom-peri                 ;; average dominance of workers in the nest periphery
  Q-eggs                     ;; number of queen-laid eggs
  W-eggs                     ;; number of worker-laid eggs
  E-eggs                     ;; number of eaten eggs

  egg-dev-time               ;; developmental time of an egg (days)
  egg-dev-stdev              ;; standard deviation of egg developmental time (days)
  larva-dev-time             ;; developmental time of a larva (days)
  larva-dev-stdev            ;; standard deviation of larval developmental time (days)
  queen-dev-time             ;; developmental time of a new queen larva (days)
  pupa-dev-time              ;; developmental time of a pupa (days)
  pupa-dev-stdev             ;; standard deviation of pupal developmental time (days)
  suppress-time              ;; max age to suppress the development of a new queen (days)
  ovipos-time                ;; duration of oviposition (days)
  worker-egg-prob            ;; probability to lay egg as a worker
  first-brood                ;; initial number of eggs to start the colony

  init-honey                 ;; initial amount of food in the honey pot
  max-bite                   ;; maximum amount of food to eat
  larva-bite                 ;; amount of food fed to a worker larva
  queen-bite                 ;; amount of food fed to a queen larva
  queen-food                 ;; minimum amount of food to induce new queen development
  digest-rate                ;; amount of food used per day
  eating-time                ;; duration of eating event
  new-honey                  ;; amount of food added by a foraging event
  foraging-time              ;; duration of foraging event

  queen-dom-init             ;; initial dominance of the queen
  worker-dom-init            ;; initial dominance of the workers
  step-dom                   ;; dominance scaling factor
  center-time                ;; maximum idle time to stay in the nest center
  stress-drone               ;; stress treshold to lay drone eggs
  stress-kill                ;; stress treshold to leave the nest
  activation-time            ;; maximum idle time to next activation
]

breed [ queens queen ]
breed [ workers worker ]
breed [ drones drone ]
breed [ new-queens new-queen ]
breed [ eggs egg ]
breed [ larvae larva ]
breed [ pupae pupa ]

queens-own [
  dom                 ;; dominance value determining social rank
  food                ;; amount of food in stomach
  stress              ;; amount of stress during oviposition events
  wait-time           ;; counter to monitor the time between interactions
  ovi-time            ;; counter to monitor the duration of oviposition
  eat-time            ;; counter to monitor the duration of eating
  ovi?                ;; boolean variable: true if oviposition was succesful, false otherwise; use to determine if an egg is laid
  out?                ;; boolean variable: true if worker is outside the nest, false otherwise; always false for a queen!
]

workers-own [
  dom                 ;; dominance value determining social rank
  food                ;; amount of food in stomach
  wait-time           ;; counter to monitor the time between interactions
  ovi-time            ;; counter to monitor the duration of oviposition
  eat-time            ;; counter to monitor the duration of eating
  out-time            ;; counter to monitor the duration of eating
  ovi?                ;; boolean variable: true if oviposition was succesful, false otherwise; use to determine if an egg is laid
  out?                ;; boolean variable: true if worker is outside the nest, false otherwise; use to distinguish foragers
]

eggs-own [
  sex                 ;; indicates whether the egg will become a drone ("D"), a worker ("W") or a new queen ("Q")
  age                 ;; counter to monitor the developmental time
  motherID            ;; ID-number of agent that laid the egg; use to check whether an egg should be eaten
]

larvae-own [
  sex                 ;; indicates whether the larva will become a drone ("D"), a worker ("W") or a new queen ("Q")
  age                 ;; counter to monitor the developmental time
  food                ;; amount of food in stomach
]

pupae-own [
  sex                 ;; indicates whether the pupa will become a drone ("D"), a worker ("W") or a new queen ("Q")
  age                 ;; counter to monitor the developmental time
]

new-queens-own [  ]   ;; no parameters needed
drones-own [  ]       ;; no parameters needed

patches-own [
  honey               ;; amount of honey: zero for all patches but the honey pot
  honey-pot?          ;; boolean variable: true if patch is part of the honey pot, false otherwise
  nest-center?        ;; boolean variable: true if patch is part of the nest center, false otherwise
  nest-peri?          ;; boolean variable: true if patch is part of the nest periphery, false otherwise
  outside?            ;; boolean variable: true if patch is not part of the nest, false otherwise
]

to init-globals
  set days 0
  set egg-dev-time 4                   ;; days
  set egg-dev-stdev 1                  ;; days
  set larva-dev-time 7                 ;; days
  set larva-dev-stdev 2                ;; days
  set queen-dev-time 10                ;; 7 plus 3 extra days
  set pupa-dev-time 10                 ;; days
  set pupa-dev-stdev 2                 ;; days
  set suppress-time 4                  ;; days
  set ovipos-time 0.04                 ;; days
  set worker-egg-prob 0.01             ;; probability to lay eggs as a worker
  set first-brood 5                    ;; workers
  set init-honey 10
  set max-bite 1
  set larva-bite 0.2
  set queen-bite 0.3
  set queen-food 5.5
  set digest-rate (0.2 / 100)          ;; food/day recalculated as food/tick
  set eating-time 0.2                  ;; days
  set new-honey 2
  set foraging-time 0.3                ;; days
  set queen-dom-init 7.5
  set worker-dom-init 1
  set step-dom 0.15                    ;; default = 0.15
  set center-time 0.15                 ;; days
  set stress-drone 1
  set stress-kill 3
  set activation-time 0.1              ;; days

  set W-dom-center worker-dom-init
  set W-dom-peri worker-dom-init
  set Q-eggs 0
  set W-eggs 0
  set E-eggs 0
end

to setup-nest                          ;; patch procedure
    set outside? true
    set nest-center? (distancexy 0 0) < (0.6 * max-pxcor)
    set nest-peri? (distancexy 0 0) < (0.8 * max-pxcor)
    set honey-pot? (distancexy 0 (0.7 * max-pycor)) < 6
    set pcolor green
    set honey 0
    if nest-center?
    [
      set nest-peri? false
      set honey-pot? false
      set outside? false
      set pcolor sky
    ]
    if honey-pot?
    [
      set nest-center? false
      set nest-peri? false
      set outside? false
      set pcolor yellow
      set honey init-honey
    ]
    if nest-peri?
    [
      set nest-center? false
      set honey-pot? false
      set outside? false
      set pcolor blue
    ]
end


to setup-colony
  set-default-shape eggs "circle"
  set-default-shape larvae "bug"
  set-default-shape pupae "hex"
  set-default-shape queens "bee"
  set-default-shape new-queens "bee"
  set-default-shape workers "bee"
  set-default-shape drones "bee"
  create-queens 1
  [
    set size 5
    set color orange
    set dom queen-dom-init
    set wait-time 0
    set ovi-time 0
    set eat-time 0
    set ovi? true
    set out? false
    set food max-bite
    set stress 0
    while [count eggs < first-brood]
    [
      lay-egg set Q-eggs Q-eggs + 1
    ]
  ]
end


to setup
  clear-all
  init-globals
  ask patches
  [ setup-nest ]
  setup-colony
  reset-ticks
end


to go
;  if (ticks mod 100 = 0) [set days days + 1 ask (turtle-set eggs larvae pupae) [ set age age + 1 ] ]
;  if (days = 270)
;  [ stop ]
;  ask  workers  ;; update foraging
;  [
;    if (out-time > 0)
;    [
;      set out-time out-time - 1
;    ]
;    if (out? and (out-time = 0))
;    [
;      ask patches with [ honey-pot? ]
;      [
;        set honey honey + new-honey
;      ]
;      move-to one-of patches with [ honey-pot? ]
;      set out? false
;      set eat-time (eating-time * 100)
;    ]
;  ]
;
;  ask (turtle-set queens workers)  ;; update eating
;  [
;   if (food > 0)
;   [
;     set food food - digest-rate
;   ]
;   ifelse (is-worker? self)
;   [
;     if (not out? and eat-time = 0 and food <= 0)
;     [ eat ]
;   ]
;   [
;     if (food <= 0)
;     [ eat ]
;   ]
;   if (eat-time > 0)
;   [
;     set eat-time eat-time - 1
;     if (eat-time = 0)
;     [
;       move-to one-of patches with [ nest-center? ]
;     ]
;    ]
;  ]
;  ask (turtle-set queens workers)  ;; update ovipositing and waiting time & check for activation
;  [
;    if (ovi-time > 0)
;    [
;      set ovi-time ovi-time - 1
;      if (ovi-time = 0)
;      [
;        ifelse (is-queen? self)
;        [
;          lay-egg
;          set Q-eggs Q-eggs + 1
;        ]
;        [
;          if (ovi?)
;          [
;            lay-egg set W-eggs W-eggs + 1
;          ]
;        ]
;      ]
;    ]
;    set wait-time wait-time + 1
;    if ((ovi-time = 0) and (eat-time = 0) and (not out?))  ;; no activations take place while eating, foraging or ovipositing
;    [
;    if (is-worker? self)
;    [
;      if ((wait-time > (center-time * 100)) and ([ nest-center? ] of patch-here))
;      [
;        move-to one-of patches with [ nest-peri? ]
;        ]
;      ]
;      if (wait-time > (activation-time * 100) / dom)
;    [
;      if ([ nest-peri? ] of patch-here)
;      [
;        move-to one-of patches with [ nest-center? ]
;        ]
;      do-activation
;      set wait-time 0
;      ]
;    ]
;  ]
;
;  ask eggs                         ;; update the age of the eggs
;  [
;    if (age > random-normal egg-dev-time egg-dev-stdev)
;    [
;      set breed larvae
;      set size 2
;      set color white
;      set age 0
;      set food 0
;    ]
;  ]
;
;  ask larvae                       ;; update the age of the larvae
;  [
;    ifelse (sex = "Q")
;    [
;      if (age > random-normal queen-dev-time larva-dev-stdev)
;      [
;        set breed pupae
;        set size 2
;        set color white
;        set age 0
;      ]
;    ]
;    [
;      if (age > random-normal larva-dev-time larva-dev-stdev)
;      [
;        set breed pupae
;        set size 2
;        set color white
;        set age 0
;      ]
;    ]
;  ]
;
;  ask pupae                        ;; update the age of the pupae
;  [
;    if (age > random-normal pupa-dev-time pupa-dev-stdev)
;    [
;      ifelse (sex = "Q")
;      [
;        set breed new-queens
;        set size 3
;        set color orange
;      ]
;      [
;        ifelse (sex = "W")
;        [
;          set breed workers
;          set size 2
;          set color red
;          set wait-time 0
;          set dom worker-dom-init
;          set eat-time 0
;          set out-time 0
;          set out? false
;          set ovi? false
;        ]
;        [
;          set breed drones
;          set size 3
;          set color black
;        ]
;      ]
;    ]
;  ]
;   ;; update the output parameters to plot in your graphs
;  if (any? workers-on patches with [ nest-center? ])
;  [
;    set W-dom-center mean [ dom ] of workers-on patches with [ nest-center? ]
;  ]
;  if (any? workers-on patches with [ nest-peri? ])
;  [
;    set W-dom-peri mean [ dom ] of workers-on patches with [ nest-peri? ]
;  ]
;  tick
end


to do-activation                    ;; turtle procedure
 ; create a local variable called bumble (what was the difference between let and set?)
 ; is the interaction partner larvae pupa worker? consider the functions that should be called if any of these
 ; if the interaction partner is pupa, what role does the ovi-time variable play?
end


to do-dom-interaction [bumble]      ;; turtle procedure

;tips
; The equations for dominance interaction can be found both in the paper and the exercise
; Is the bumble or the focal individual a worker? make sure to change ovi? - read the paper why (when do workers lay eggs?)
; Is the bumble or the focal individual a queen? What happens to her stress levels?


end


to lay-egg                          ;; turtle procedure
  move-to one-of patches with [ nest-center? ]
  ifelse (is-queen? self)
  [
    ifelse (stress > stress-drone)
    [
      hatch-eggs 1
      [
        set size 1
        set color white
        set age 0
        set motherID [who] of myself
        set sex "D"
      ]
    ]
    [
      hatch-eggs 1
      [
        set size 1
        set color white
        set age 0
        set motherID [who] of myself
        set sex "W"
      ]
    ]
    ifelse (stress > stress-kill)
    [ die ]
    [ set stress 0 ]
  ]
  [
    if (ovi?)
    [
      hatch-eggs 1
      [
        set size 1
        set color white
        set age 0
        set motherID [who] of myself
        set sex "D"
      ]
      set ovi? false
    ]
  ]
end


to eat-egg [bumble]                 ;; turtle procedure
   ;is the eater a queen or a worker?
   ; is the egg layed by themselves? (motherID)
   ; what is the E-eggs variable? how should this change?

end


to feed [bumble]                    ;; turtle procedure

 ;tips
 ;Is the feeder a queen or a worker?
 ; What do queens do when they notice a queen-larvae? something with inhibition?
 ; When do queens feed the larvae? What time period?
 ; How much food is given to queen larvae or worker larvae? Where is the food coming from, and should that resource decrease when giving food?
 ; when there is insufficient food in that resource, the larvae should not get food that time.
 ; When do larvae turn into queen-larvae? (sex = "Q" or sex = "W")

end


to oviposit [bumble]                ;; turtle procedure
 ;tips
 ;how probable is it that the queen lays an egg?
 ; how probable is it that a worker lays an egg?
 ; what is ovi-time? what happens to it?
end


to eat                              ;; turtle procedure
; things to think of: how much food?
; to where does the bee move?
; what is the relation between the dominance and the bite to eat?
; what is the equation for determining when the bee goes foraging?
; if the bee should go foraging, call the function 'forage'.
; if the bite that the bee wants to take, is larger than the amount available at the patch, the amount eaten should equal the amount available
; the amount of honey eaten, should be removed from the source

end


to forage                           ;; turtle procedure
; to where should the bee move?
; how long should it stay there? (think of the variable out-time)
; what does the variable out? do?
end

@#$#@#$#@
GRAPHICS-WINDOW
769
29
1484
745
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
66
54
130
87
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
67
108
130
141
Run
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
