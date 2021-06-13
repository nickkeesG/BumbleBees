;; The bumblebee model uses days as unit of time, and simulates a colony year-round (270 days; queens overwinter solo and start a new colony next spring)
;; 0.01 day is the smallest time unit used (== tick): 1 day == 100 ticks

globals
[
  days
  W-dom-center
  W-dom-peri
  Q-eggs
  W-eggs
  E-eggs

  egg-dev-time
  egg-dev-stdev
  larva-dev-time
  larva-dev-stdev
  queen-dev-time
  pupa-dev-time
  pupa-dev-stdev
  suppress-time
  pupa-ovipos-time
  pupa-full-prob
  ovipos-time
  build-cell-time
  eat-egg-prob
  worker-egg-prob     ;; probability to lay egg as a worker
  first-brood

  init-honey
  max-bite
  larva-bite
  queen-bite
  queen-food
  digest-rate
  eating-time
  new-honey
  foraging-time

;;  queen-dom-init
;;  worker-dom-init
;;  step-dom
  center-time
  stress-drone
  stress-kill
  activation-time
]

breed [ queens queen ]
breed [ workers worker ]
breed [ drones drone ]
breed [ new-queens new-queen ]
breed [ eggs egg ]
breed [ larvae larva ]
breed [ pupae pupa ]

queens-own [ dom food stress wait-time ovi-time eat-time ovi? out?]
workers-own [ dom food wait-time ovi-time eat-time out-time out? ovi? ]
new-queens-own [  ]
drones-own [  ]
eggs-own [ sex age motherID ]
larvae-own [ sex age food ]
pupae-own [ sex age ]

patches-own
[
  honey
  honey-pot?
  nest-center?
  nest-peri?
  outside?
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
  set pupa-ovipos-time 3               ;; days
  set pupa-full-prob 0.6
  set ovipos-time 0.04                 ;; days
  set build-cell-time 0.15             ;; days
  set eat-egg-prob 0.1                 ;; default = 1.0
  set worker-egg-prob 0.01
  set first-brood 5                    ;; workers
  set init-honey 10
  set max-bite 1
  set larva-bite 0.2
  set queen-bite 0.3
  set queen-food 5.5
  set digest-rate (0.2 / 100)          ;; food/day recalculated as food/tick
  set eating-time 0.2                  ;; days
  set new-honey 2
  set foraging-time 0.3                   ;; days
;;  set queen-dom-init 7.5
;;  set worker-dom-init 1
;;  set step-dom 0.15                    ;; default = 0.15
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
    [ set nest-peri? false
      set honey-pot? false
      set outside? false
      set pcolor sky
    ]
    if honey-pot?
    [ set nest-center? false
      set nest-peri? false
      set outside? false
      set pcolor yellow
      set honey init-honey
    ]
    if nest-peri?
    [ set nest-center? false
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
  [ set size 5
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
  [
    setup-nest
  ]
  setup-colony
  reset-ticks
end


to go
  if (ticks mod 100 = 0)
  [
    set days days + 1
    ask (turtle-set eggs larvae pupae)
    [
      set age age + 1
    ]
  ]
  if (days = 270)
  [ stop ]

  ask  workers  ;; update foraging
  [ if (out-time > 0)
    [
      set out-time out-time - 1
    ]
    if (out? and (out-time = 0))
    [
      ask patches with [ honey-pot? ]
      [
        set honey honey + new-honey
      ]
      move-to one-of patches with [ honey-pot? ]
      set out? false
      set eat-time (eating-time * 100) ]
  ]

  ask (turtle-set queens workers)  ;; update eating
  [ if (food > 0)
    [
      set food food - digest-rate
    ]
    ifelse (is-worker? self)
    [
      if (not out? and eat-time = 0 and food <= 0)
      [ eat ]
    ]
    [
      if (food <= 0)
      [ eat ]
    ]
    if (eat-time > 0)
    [
      set eat-time eat-time - 1
      if (eat-time = 0)
      [
        move-to one-of patches with [ nest-center? ]
      ]
    ]
  ]

  ask (turtle-set queens workers)  ;; update ovipositing and waiting time & check for activation
  [
    if (ovi-time > 0)
    [ set ovi-time ovi-time - 1
      if (ovi-time = 0)
      [ ifelse (is-queen? self)
        [
          lay-egg
          set Q-eggs Q-eggs + 1
        ]
        [
          if (ovi?)
          [
            lay-egg set W-eggs W-eggs + 1
          ]
        ]
      ]
    ]
    set wait-time wait-time + 1
    if ((ovi-time = 0) and (eat-time = 0) and (not out?))  ;; no activations take place while eating, foraging or ovipositing
    [
      if (is-worker? self)
      [
        if ((wait-time > (center-time * 100)) and ([ nest-center? ] of patch-here))
        [
          move-to one-of patches with [ nest-peri? ]
        ]
      ]
      if (wait-time > (activation-time * 100) / dom)
      [
        if ([ nest-peri? ] of patch-here)
        [
          move-to one-of patches with [ nest-center? ]
        ]
        do-activation
        set wait-time 0
      ]
    ]
  ]

  ask eggs
  [
    if (age > random-normal egg-dev-time egg-dev-stdev)
    [
      set breed larvae
      set size 2
      set color white
      set age 0
      set food 0
    ]
  ]

  ask larvae
  [
    ifelse (sex = "Q")
    [
      if (age > random-normal queen-dev-time larva-dev-stdev)
      [
        set breed pupae
        set size 2
        set color white
        set age 0
      ]
    ]
    [
      if (age > random-normal larva-dev-time larva-dev-stdev)
      [
        set breed pupae
        set size 2
        set color white
        set age 0
      ]
    ]
  ]

  ask pupae
  [
    if (age > random-normal pupa-dev-time pupa-dev-stdev)
    [
      ifelse (sex = "Q")
      [
        set breed new-queens
        set size 3
        set color orange
      ]
      [
        ifelse (sex = "W")
        [
          set breed workers
          set size 2
          set color red
          set wait-time 0
          set dom worker-dom-init
          set eat-time 0
          set out-time 0
          set out? false
          set ovi? false
        ]
        [
          set breed drones
          set size 3
          set color black
        ]
      ]
    ]
  ]

  if (any? workers-on patches with [ nest-center? ])
  [
    set W-dom-center mean [ dom ] of workers-on patches with [ nest-center? ]
  ]
  if (any? workers-on patches with [ nest-peri? ])
  [
    set W-dom-peri mean [ dom ] of workers-on patches with [ nest-peri? ]
  ]
  tick
end


to do-activation                    ;; turtle procedure
  let bumble one-of other (turtle-set queens eggs larvae pupae workers-on patches with [ nest-center? ])
  if (is-worker? bumble or is-queen? bumble)
  [
    do-dom-interaction bumble
  ]
  if (is-egg? bumble)
  [
    eat-egg bumble
  ]
  if (is-larva? bumble)
  [
    feed bumble
  ]
  if (is-pupa? bumble)
  [
    if (ovi-time = 0)
    [
      oviposit bumble
    ]
]
end


to do-dom-interaction [bumble]      ;; turtle procedure
  let R dom / (dom + [dom] of bumble)
  let K 0
  if (R > random-float 1.0)
  [
    set K 1
  ]  ;; self = winner, bumble = loser
  set dom dom + ((K - R) * step-dom)
  if (dom < 0.1)
  [
    set dom 0.1
  ]

  ask bumble
  [
    set dom dom - ((K - R) * step-dom)
    if (dom < 0.1)
    [ set dom 0.1
    ]
  ]

  if (is-worker? self)
  [ ifelse (K = 1)
    [
      set ovi? true
    ]
    [
      set ovi? false
    ]
  ]
  if (is-worker? bumble)
  [
    ifelse (K = 0)
    [
      ask bumble
      [
        set ovi? true
      ]
    ]
    [
      ask bumble
      [
        set ovi? false
      ]
    ]
  ]
  if ((is-queen? self) and (ovi-time > 0)) [ ifelse (K = 1) [ set stress stress + 1 ] [ set stress stress + 2 ] ]
  if ((is-queen? bumble) and ([ ovi-time ] of bumble > 0)) [ ifelse (K = 0) [ ask bumble [ set stress stress + 1 ] ] [ ask bumble [ set stress stress + 2 ] ] ]
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
      ] set ovi? false
    ]
  ]
end


to eat-egg [bumble]
  if (is-queen? self)
  [
    if ([motherID] of bumble != [who] of self)
    [
      ask bumble
      [ die ]
      set E-eggs E-eggs + 1
    ]
  ]
  if (is-worker? self and not any? queens)
  [
    if ([motherID] of bumble != [who] of self)
    [
      ask bumble
      [ die ]
      set E-eggs E-eggs + 1
    ]
  ]
end


to feed [bumble]                    ;; turtle procedure
  if (is-queen? self)
  [
    if (([sex] of bumble = "Q") and ([age] of bumble < suppress-time))
    [
      ask bumble
      [
        set sex "W"
      ]
    ]
  ]
  if((is-worker? self) or (is-queen? self and not any? workers))
  [
    ifelse ([sex] of bumble = "Q")
    [
      if (food > queen-bite)
      [
        ask bumble
        [
          set food food + queen-bite
        ]
        set food food - queen-bite
      ]
    ]
    [ if (food > larva-bite)
      [ ask bumble
        [ set food food + larva-bite
          if ((food > queen-food) and (sex = "W"))
          [
            set sex "Q"
          ]
        ]
        set food food - larva-bite
      ]
    ]
  ]
end


to oviposit [bumble]                ;; turtle procedure
  if ((is-queen? self) or (is-worker? self and random-float 1.0 < worker-egg-prob))
  [
    move-to one-of patches with [ nest-center? ]
    set ovi-time (ovipos-time * 100)
  ]
end


to eat                              ;; turtle procedure
  move-to one-of patches with [ honey-pot?]
  let pot [honey] of patch-here
  let bite max-bite
  if (dom < 1)
  [
    set bite (bite * dom)
  ]
  ifelse (pot < (1 / (dom + bite)))
  [
    if (is-worker? self) [ forage ]
  ]
  [
    if (pot < bite)
    [
      set bite pot
    ]
    set food food + bite
    set eat-time (eating-time * 100)
    ask patches with [ honey-pot? ]
    [
      set honey honey - bite
    ]
  ]
end


to forage
  move-to one-of patches with [ outside? ]
  set out-time (foraging-time * 100)
  set out? true
end

@#$#@#$#@
GRAPHICS-WINDOW
827
10
1542
726
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
52
55
121
88
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
53
107
116
140
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

MONITOR
407
75
464
120
Days
ticks / 100
1
1
11

PLOT
33
188
761
500
Bumbles
time
number
0.0
90.0
0.0
10.0
true
true
"" ""
PENS
"drones" 1.0 0 -16777216 true "" "plot count drones"
"queens" 1.0 0 -817084 true "" "plot count new-queens"
"workers" 1.0 0 -2674135 true "" "plot count workers"
"foragers" 1.0 0 -13840069 true "" "plot count workers with [out?]"
"eggs" 1.0 0 -1184463 true "" "plot count eggs"
"larvae" 1.0 0 -5825686 true "" "plot count larvae"
"pupae" 1.0 0 -10141563 true "" "plot count pupae"

PLOT
32
524
763
745
Workers
time
average dominance
0.0
10.0
0.0
2.0
true
true
"" ""
PENS
"elite" 1.0 0 -13791810 true "" "plotxy ticks W-dom-center"
"common" 1.0 0 -13345367 true "" "plotxy ticks W-dom-peri"

MONITOR
529
21
609
66
Queen eggs
Q-eggs
17
1
11

MONITOR
528
78
611
123
Worker eggs
W-eggs
17
1
11

MONITOR
529
136
604
181
Eaten eggs
E-eggs
17
1
11

SLIDER
161
31
333
64
worker-dom-init
worker-dom-init
1
10
1.0
.1
1
NIL
HORIZONTAL

SLIDER
160
80
332
113
queen-dom-init
queen-dom-init
1
10
7.5
.1
1
NIL
HORIZONTAL

SLIDER
161
126
333
159
step-dom
step-dom
0
1
0.15
.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

## HOW TO USE IT

## THINGS TO NOTICE

## CREDITS AND REFERENCES
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

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

bird1
false
0
Polygon -7500403 true true 2 6 2 39 270 298 297 298 299 271 187 160 279 75 276 22 100 67 31 0

bird2
false
0
Polygon -7500403 true true 2 4 33 4 298 270 298 298 272 298 155 184 117 289 61 295 61 105 0 43

boat1
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

boat2
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 157 54 175 79 174 96 185 102 178 112 194 124 196 131 190 139 192 146 211 151 216 154 157 154
Polygon -7500403 true true 150 74 146 91 139 99 143 114 141 123 137 126 131 129 132 139 142 136 126 142 119 147 148 147

boat3
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 37 172 45 188 59 202 79 217 109 220 130 218 147 204 156 158 156 161 142 170 123 170 102 169 88 165 62
Polygon -7500403 true true 149 66 142 78 139 96 141 111 146 139 148 147 110 147 113 131 118 106 126 71

box
true
0
Polygon -7500403 true true 45 255 255 255 255 45 45 45

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly1
true
0
Polygon -16777216 true false 151 76 138 91 138 284 150 296 162 286 162 91
Polygon -7500403 true true 164 106 184 79 205 61 236 48 259 53 279 86 287 119 289 158 278 177 256 182 164 181
Polygon -7500403 true true 136 110 119 82 110 71 85 61 59 48 36 56 17 88 6 115 2 147 15 178 134 178
Polygon -7500403 true true 46 181 28 227 50 255 77 273 112 283 135 274 135 180
Polygon -7500403 true true 165 185 254 184 272 224 255 251 236 267 191 283 164 276
Line -7500403 true 167 47 159 82
Line -7500403 true 136 47 145 81
Circle -7500403 true true 165 45 8
Circle -7500403 true true 134 45 6
Circle -7500403 true true 133 44 7
Circle -7500403 true true 133 43 8

caterpillar
true
0
Polygon -7500403 true true 165 210 165 225 135 255 105 270 90 270 75 255 75 240 90 210 120 195 135 165 165 135 165 105 150 75 150 60 135 60 120 45 120 30 135 15 150 15 180 30 180 45 195 45 210 60 225 105 225 135 210 150 210 165 195 195 180 210
Line -16777216 false 135 255 90 210
Line -16777216 false 165 225 120 195
Line -16777216 false 135 165 180 210
Line -16777216 false 150 150 201 186
Line -16777216 false 165 135 210 150
Line -16777216 false 165 120 225 120
Line -16777216 false 165 106 221 90
Line -16777216 false 157 91 210 60
Line -16777216 false 150 60 180 45
Line -16777216 false 120 30 96 26
Line -16777216 false 124 0 135 15

circle
false
0
Circle -7500403 true true 35 35 230

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

person
false
0
Circle -7500403 true true 155 20 63
Rectangle -7500403 true true 158 79 217 164
Polygon -7500403 true true 158 81 110 129 131 143 158 109 165 110
Polygon -7500403 true true 216 83 267 123 248 143 215 107
Polygon -7500403 true true 167 163 145 234 183 234 183 163
Polygon -7500403 true true 195 163 195 233 227 233 206 159

sheep
false
15
Rectangle -1 true true 90 75 270 225
Circle -1 true true 15 75 150
Rectangle -16777216 true false 81 225 134 286
Rectangle -16777216 true false 180 225 238 285
Circle -16777216 true false 1 88 92

spacecraft
true
0
Polygon -7500403 true true 150 0 180 135 255 255 225 240 150 180 75 240 45 255 120 135

thin-arrow
true
0
Polygon -7500403 true true 150 0 0 150 120 150 120 293 180 293 180 150 300 150

truck-down
false
0
Polygon -7500403 true true 225 30 225 270 120 270 105 210 60 180 45 30 105 60 105 30
Polygon -8630108 true false 195 75 195 120 240 120 240 75
Polygon -8630108 true false 195 225 195 180 240 180 240 225

truck-left
false
0
Polygon -7500403 true true 120 135 225 135 225 210 75 210 75 165 105 165
Polygon -8630108 true false 90 210 105 225 120 210
Polygon -8630108 true false 180 210 195 225 210 210

truck-right
false
0
Polygon -7500403 true true 180 135 75 135 75 210 225 210 225 165 195 165
Polygon -8630108 true false 210 210 195 225 180 210
Polygon -8630108 true false 120 210 105 225 90 210

turtle
true
0
Polygon -7500403 true true 138 75 162 75 165 105 225 105 225 142 195 135 195 187 225 195 225 225 195 217 195 202 105 202 105 217 75 225 75 195 105 187 105 135 75 142 75 105 135 105

wolf
false
0
Rectangle -7500403 true true 15 105 105 165
Rectangle -7500403 true true 45 90 105 105
Polygon -7500403 true true 60 90 83 44 104 90
Polygon -16777216 true false 67 90 82 59 97 89
Rectangle -1 true false 48 93 59 105
Rectangle -16777216 true false 51 96 55 101
Rectangle -16777216 true false 0 121 15 135
Rectangle -16777216 true false 15 136 60 151
Polygon -1 true false 15 136 23 149 31 136
Polygon -1 true false 30 151 37 136 43 151
Rectangle -7500403 true true 105 120 263 195
Rectangle -7500403 true true 108 195 259 201
Rectangle -7500403 true true 114 201 252 210
Rectangle -7500403 true true 120 210 243 214
Rectangle -7500403 true true 115 114 255 120
Rectangle -7500403 true true 128 108 248 114
Rectangle -7500403 true true 150 105 225 108
Rectangle -7500403 true true 132 214 155 270
Rectangle -7500403 true true 110 260 132 270
Rectangle -7500403 true true 210 214 232 270
Rectangle -7500403 true true 189 260 210 270
Line -7500403 true 263 127 281 155
Line -7500403 true 281 155 281 192

wolf-left
false
3
Polygon -6459832 true true 117 97 91 74 66 74 60 85 36 85 38 92 44 97 62 97 81 117 84 134 92 147 109 152 136 144 174 144 174 103 143 103 134 97
Polygon -6459832 true true 87 80 79 55 76 79
Polygon -6459832 true true 81 75 70 58 73 82
Polygon -6459832 true true 99 131 76 152 76 163 96 182 104 182 109 173 102 167 99 173 87 159 104 140
Polygon -6459832 true true 107 138 107 186 98 190 99 196 112 196 115 190
Polygon -6459832 true true 116 140 114 189 105 137
Rectangle -6459832 true true 109 150 114 192
Rectangle -6459832 true true 111 143 116 191
Polygon -6459832 true true 168 106 184 98 205 98 218 115 218 137 186 164 196 176 195 194 178 195 178 183 188 183 169 164 173 144
Polygon -6459832 true true 207 140 200 163 206 175 207 192 193 189 192 177 198 176 185 150
Polygon -6459832 true true 214 134 203 168 192 148
Polygon -6459832 true true 204 151 203 176 193 148
Polygon -6459832 true true 207 103 221 98 236 101 243 115 243 128 256 142 239 143 233 133 225 115 214 114

wolf-right
false
3
Polygon -6459832 true true 170 127 200 93 231 93 237 103 262 103 261 113 253 119 231 119 215 143 213 160 208 173 189 187 169 190 154 190 126 180 106 171 72 171 73 126 122 126 144 123 159 123
Polygon -6459832 true true 201 99 214 69 215 99
Polygon -6459832 true true 207 98 223 71 220 101
Polygon -6459832 true true 184 172 189 234 203 238 203 246 187 247 180 239 171 180
Polygon -6459832 true true 197 174 204 220 218 224 219 234 201 232 195 225 179 179
Polygon -6459832 true true 78 167 95 187 95 208 79 220 92 234 98 235 100 249 81 246 76 241 61 212 65 195 52 170 45 150 44 128 55 121 69 121 81 135
Polygon -6459832 true true 48 143 58 141
Polygon -6459832 true true 46 136 68 137
Polygon -6459832 true true 45 129 35 142 37 159 53 192 47 210 62 238 80 237
Line -16777216 false 74 237 59 213
Line -16777216 false 59 213 59 212
Line -16777216 false 58 211 67 192
Polygon -6459832 true true 38 138 66 149
Polygon -6459832 true true 46 128 33 120 21 118 11 123 3 138 5 160 13 178 9 192 0 199 20 196 25 179 24 161 25 148 45 140
Polygon -6459832 true true 67 122 96 126 63 144
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
