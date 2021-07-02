globals [
  days ;;1 day = 100 ticks
  honey

  ;DATA COLLECTION LISTS
  time-low-c
  time-low-p
  time-low-o
  time-med-c
  time-med-p
  time-med-o
  time-high-c
  time-high-p
  time-high-o
]

patches-own [
  region ;; 3 regions: "outside" "periphery" and "center"
  honeypot? ;;Is this patch a honeypot?
  egg-here? ;;Is there an egg developing here?
  larva-pupa-here? ;;Is there a larva or a pupa developing here?
]

turtles-own [
  ;SIMULATION VARIABLES
  dom
  age
  food
  task
  task-destination
  busy?
  in-flight?
  dev-time
  ovi-wait-time
  flowers-visited
  stress
  sex

  ;DATA COLLECTION VARIABLES
  x-coords
  y-coords
  locs    ;; record of the region at each tick
  rand-id ;; a random id which does not relate to when a turtle is born
]

breed [queens queen]
breed [newQueens newQueen]
breed [pupae pupa]
breed [workers worker]
breed [drones drone]
breed [larvae larva]
breed [eggs egg]

;;CONFIG METHODS - for generating new members of each breed
to queen.config
  set dom queen-dom-init
  set color black
  set xcor 0
  set ycor 0
  set age 0
  set food 1
  set busy? False
  set ovi-wait-time 0
  set in-flight? False
  set size 2
  set stress 0
  data-collect.config
end

to worker.config
  set dom worker-dom-init
  set color orange
  set age 0
  set in-flight? False
  set size 1.5
  set task "no-task"
  set rand-id random 10000
  data-collect.config
end

to egg.config
  set dev-time random-normal egg-hatch-time-mean egg-hatch-time-std
  set age 0
  set color black
  set shape "circle"
  set size 0.5
end

to larva.config
  set dev-time random-normal larva-dev-time-mean larva-dev-time-std
  set age 0
  set color blue
  set shape "circle"
end

to pupa.config
  set dev-time random-normal pupa-dev-time-mean pupa-dev-time-std
  set age 0
  set color green
  set shape "triangle"
  set size 1
end

to drone.config
  set size 1.5
  set color grey
  set task "no-task"
  set in-flight? False
end

to data-collect.config
  set x-coords []
  set y-coords []
  set locs []
end

;;SETUP METHODS
to setup
  clear-all
  set days 0
  set honey 10
  set-data-globals
  setup-patches
  create-queens 1 [ queen.config ]
  reset-ticks
end

to set-data-globals
  set time-low-c []
  set time-low-p []
  set time-low-o []
  set time-med-c []
  set time-med-p []
  set time-med-o []
  set time-high-c []
  set time-high-p []
  set time-high-o []
end

to setup-patches
  ask patches [
    set honeypot? False
    set egg-here? False
    set larva-pupa-here? False

    let distFromCenter sqrt (pxcor * pxcor + pycor * pycor)
    if distFromCenter < 14 [
      set pcolor white
      set region "center"
    ]
    if distFromCenter >= 14 and distFromCenter < 26 [
      set pcolor blue
      set region "periphery"
    ]
    if distFromCenter >= 26 [
      set pcolor green
      set region "outside"
    ]

    ;;The first honeypot is generated by default at the origin.
    if (pxcor = 0) and (pycor = 0) [
      set honeypot? True
      set pcolor yellow
    ]
  ]
end

;;ALL OTHER METHODS
to go
  ask (turtle-set queens workers drones) [
    ifelse busy? [
      ifelse patch-here = task-destination [ finish-task ] [ ifelse in-flight? [ fd 1 ] [ fd 0.2 ] ]
    ]
    [
      select-task
    ]
  ]
  ask eggs [
    if age >= dev-time [
      ask patch-here [
        set egg-here? False
        set larva-pupa-here? True
      ]
      set breed larvae
      larva.config
    ]
  ]
  ask larvae [
    if age >= dev-time [
      set breed pupae
      pupa.config
    ]
  ]
  ask pupae [
    if age >= dev-time [
      ask patch-here [set larva-pupa-here? False]
      if sex = "W" [
        set breed workers
        worker.config
      ]
      if sex = "D" [
        set breed drones
        drone.config
      ]
    ]
  ]

  collect-data
  increment-model-time
end

to select-task  ;; here a bee decides what to do
  if is-queen? self or is-worker? self [
    if not busy? [
      if food <= 0 [
        eat-honey
        set busy? True
      ]
    ]
    if not busy? [
      if count turtles with [task = "build-honeypot"] = 0 [
        if (get-expected-honey / count patches with [honeypot?]) > max-honey-per-pot [
          build-honeypot
          set busy? True
        ]
      ]
    ]
    if not busy? [
      if (get-expected-honey / count patches with [honeypot?]) < min-honey-per-pot [
        forage
        set busy? True
      ]
    ]
    if not busy? [ ;; move somewhere and lay an egg
      if (is-queen? self) and ovi-wait-time <= 0 [
        lay-egg
        set busy? True
      ]
    ]
    if not busy? [ ;; dominate a nearby bee
      if dominance-behavior? [
        let nearest-bee min-one-of other (turtle-set queens workers) with [not in-flight?] [distance myself]
        if (not (nearest-bee = NOBODY)) and (distance nearest-bee <= dominance-radius) [
          dominate nearest-bee ;; if the bee loses the dominance interaction, it will select the task "flee"
        ]
      ]
    ]
  ]
  if not busy? [
    no-task ;; if the bee doesn't select any of the other tasks, it defaults to "no-task"
    set busy? True
  ]
end

to eat-honey
  set task-destination min-one-of patches with [honeypot?] [distance myself]
  set heading towards task-destination
  set task "eat-honey"
end

to-report get-expected-honey ;;count the amount of honey, including the amount that will be collected by bees
                             ;;heading out to forage or returning. This prevents all bees from foraging at once.
  report (honey + (forage-load * (count (turtles-on patches with [not (region = "outside")])
    with [task = "forage" or task = "return"])))
end

to build-honeypot
  let center-patches patches with [region = "center"] ; variable introduced to improve time-complexity.
  let patches-near-honeypot center-patches with [
    distance min-one-of center-patches with [honeypot?] [distance self] <= honeypot-max-dist
  ]

  let valid-patches patches-near-honeypot with [
    not honeypot? and not egg-here? and not larva-pupa-here?
  ]

  set task-destination one-of valid-patches
  set heading towards task-destination
  set task "build-honeypot"
end

to forage
  set task-destination one-of patches with [region = "outside"]
  set heading towards task-destination
  set in-flight? True ;;bees move faster when flying, and also cannot be dominated during this time
  set task "forage"
  set flowers-visited 0
end

to lay-egg
  let center-patches patches with [region = "center"] ;variable introduced to improve time-complexity
  let patches-near-eggs center-patches with [
     distance (min-one-of center-patches with [egg-here? or (pxcor = 0 and pycor = 0)] [distance self]) <= max-dist-egg-egg
  ]

  let patches-near-honeypot patches-near-eggs with [
    distance (min-one-of center-patches with [honeypot?] [distance self]) <= max-dist-honey-egg
  ]

  let valid-patches patches-near-honeypot with [
    (not honeypot?) and (not egg-here?) and (not larva-pupa-here?)
  ]

  set task-destination one-of valid-patches
  set heading towards task-destination
  set task "lay-egg"
end

to dominate [nearest-bee]
  let p dom / (dom + [dom] of nearest-bee)

  if age-dominance [
    set p age / (age + [age] of nearest-bee)
  ]

  let k 0
  if (random-float 1 < p) [
    set k 1
  ]
  set dom max list (dom + ((k - p) * dom-step)) 0.1
  ask nearest-bee [ set dom max list (dom - ((k - p) * dom-step)) 0.1]

  if ((is-queen? self) and (busy?) and (task = "lay-egg") and (task-destination = patch-here))
    [ ifelse (k = 1) [set stress stress + 1] [set stress stress + 2]]
  if ((is-queen? nearest-bee) and ([(busy?) and (task = "lay-egg") and (task-destination = patch-here)] of nearest-bee = True)) [ ifelse (k = 1)
    [ask nearest-bee [set stress stress + 1]] [ ask nearest-bee [set stress stress + 2]]]

  ifelse k = 1 [
    ask nearest-bee [ flee myself ]
  ]
  [
    flee nearest-bee
  ]
end

to flee [other-bee]
  set heading towards other-bee
  rt 180
  set task-destination one-of patches in-cone (flee-distance + 1) 20 with [distance myself > (flee-distance - 1)]
  set heading towards task-destination
  set task "flee"
  set color violet
  set busy? True
end

to no-task
  set task "no-task"
  set task-destination one-of patches with [not (region = "outside") and (distance myself < 4)]
  if task-destination = NOBODY [ set task-destination min-one-of patches with [not (region = "outside")] [distance myself]]
  set heading towards task-destination
end

;Here, the final step of any task is executed.
to finish-task
  if task = "eat-honey" [
    let bite min list dom 1
    set honey honey - bite
    set food food + bite
    set busy? False
  ]
  if task = "build-honeypot" [
    ask patch-here [
      set honeypot? True
      set pcolor yellow
    ]
    set busy? False
  ]
  if task = "return" [
    set honey honey + forage-load
    set in-flight? False
    set busy? False
  ]
  if task = "forage" [
    ifelse flowers-visited = flowers-per-forage [
      set task "return"
      set task-destination one-of patches with [honeypot?]
      set heading towards task-destination
    ]
    [
      set task-destination one-of patches with [region = "outside" and (distance myself < 5)]
      if task-destination = NOBODY [ set task-destination one-of patches with [region = "outside"] ]
      set heading towards task-destination
      set flowers-visited flowers-visited + 1
    ]
  ]
  if task = "lay-egg" [
    let egg-sex "W"
    if (is-queen? self and stress > stress-fert-threshold) or (is-worker? self) [
      set egg-sex "D"
    ]
    ask patch-here [set egg-here? True]
    hatch-eggs 1 [
      egg.config
      set sex egg-sex
    ]
    set ovi-wait-time oviposit-time
    set busy? False
  ]
  if task = "no-task" [
    set busy? False
  ]
  if task = "flee" [
    ifelse is-queen? self [
      set color black
    ]
    [
      set color orange
    ]
    set busy? False
  ]
end

to increment-model-time
  set days days + 0.01
  ask turtles [ set age age + 0.01]
  ask (turtle-set queens workers) [ set food food - (digest-rate / 100)]
  ask queens [set ovi-wait-time ovi-wait-time - 0.01]
  ask (turtle-set workers) [
    if age > 28 [
      die
    ]
  ]
  ask queens [ if stress > stress-kill-threshold [die] ]
  tick
end

;For generating smoother looking plots, return an average of several ticks
to-report smoothing-average [l]
  ifelse length l <= smoothing [ report mean l ] [ report mean sublist l 0 smoothing]
end

;Collect all the data in this tick to be used in the plots
to collect-data
  ask (turtle-set queens workers drones) [
    if not in-flight? [
      set x-coords fput xcor x-coords
      set y-coords fput ycor y-coords
    ]
    if [region] of patch-here = "outside" [ set locs fput "o" locs ]
    if [region] of patch-here = "periphery" [ set locs fput "p" locs ]
    if [region] of patch-here = "center" [ set locs fput "c" locs ]

    ;Delete old data
    if length x-coords > (data-time-window * 100) [set x-coords sublist x-coords 0 data-time-window]
    if length y-coords > (data-time-window * 100) [set y-coords sublist y-coords 0 data-time-window]
    if length locs > (data-time-window * 100) [set locs sublist locs 0 data-time-window]
  ]
  if count workers >= 3 [
    let low-doms get-dom-group "low-dom"
    set time-low-c fput mean [get-time-in self "c"] of low-doms time-low-c
    set time-low-p fput mean [get-time-in self "p"] of low-doms time-low-p
    set time-low-o fput mean [get-time-in self "o"] of low-doms time-low-o

    let med-doms get-dom-group "med-dom"
    set time-med-c fput mean [get-time-in self "c"] of med-doms time-med-c
    set time-med-p fput mean [get-time-in self "p"] of med-doms time-med-p
    set time-med-o fput mean [get-time-in self "o"] of med-doms time-med-o

    let high-doms get-dom-group "high-dom"
    set time-high-c fput mean [get-time-in self "c"] of high-doms time-high-c
    set time-high-p fput mean [get-time-in self "p"] of high-doms time-high-p
    set time-high-o fput mean [get-time-in self "o"] of high-doms time-high-o
  ]
end

;; Get the fraction of time a single bee spends in a given region
to-report get-time-in [_turtle region-code]
  let count-total 0
  foreach locs [x -> if x = region-code [set count-total count-total + 1]]
  report count-total / length locs
end

;; Get either the agentset of low, med, or high dominance workers
to-report get-dom-group [group-name]
  let sorted-workers sort-on [rand-id] workers ;if there is no dominance, group workers according to a random number
  if dominance-behavior? [ set sorted-workers sort-on [dom] workers ]

  let first-med-idx ceiling (length sorted-workers * dom-group-threshold)
  let first-high-idx floor (length sorted-workers * (1 - dom-group-threshold))

  if group-name = "low-dom" [
    report workers with [member? self sublist sorted-workers 0 first-med-idx ]
  ]
  if group-name = "med-dom" [
    report workers with [member? self sublist sorted-workers first-med-idx first-high-idx ]
  ]
  if group-name = "high-dom" [
    report workers with [member? self sublist sorted-workers first-high-idx length sorted-workers ]
  ]

  report []
end

;Get the spatial zone signature of a single bee
to-report zone-sig [ _turtle ] ;; turtle method
  ifelse length x-coords > 1 [
    let x-sd standard-deviation x-coords
    let y-sd standard-deviation y-coords
    report x-sd * y-sd
  ]
  [
    report 0
  ]
end

;Get the average spatial zone signature of an agentset
to-report zone-sigs [ a-set ]
  let relevant-agents (turtle-set a-set) with [ length x-coords > 1 ]
  ifelse count relevant-agents > 0
  [
    report mean [ zone-sig self ] of relevant-agents
  ]
  [
    report 0
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
746
10
1193
458
-1
-1
6.754
1
10
1
1
1
0
1
1
1
-32
32
-32
32
0
0
1
ticks
30.0

BUTTON
673
10
736
43
NIL
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
673
45
736
78
go
if any? turtles with [not (breed = drones)] [go]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
38
234
71
queen-dom-init
queen-dom-init
0
10
7.5
0.5
1
NIL
HORIZONTAL

SLIDER
10
73
234
106
worker-dom-init
worker-dom-init
0
5
1.0
0.5
1
NIL
HORIZONTAL

SLIDER
493
365
717
398
dominance-radius
dominance-radius
0
32
3.0
1
1
patches
HORIZONTAL

SLIDER
243
38
467
71
egg-hatch-time-mean
egg-hatch-time-mean
0
10
4.0
0.5
1
days
HORIZONTAL

SLIDER
243
73
467
106
egg-hatch-time-std
egg-hatch-time-std
0
5
1.4
0.1
1
days
HORIZONTAL

SLIDER
11
213
235
246
digest-rate
digest-rate
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
491
105
715
138
honeypot-max-dist
honeypot-max-dist
0
10
5.0
1
1
patches
HORIZONTAL

SLIDER
10
249
234
282
oviposit-time
oviposit-time
0
0.1
0.04
0.01
1
days
HORIZONTAL

SLIDER
491
185
715
218
max-dist-egg-egg
max-dist-egg-egg
0
10
3.0
1
1
patches
HORIZONTAL

SLIDER
493
145
717
178
max-dist-honey-egg
max-dist-honey-egg
0
10
7.0
1
1
patches
HORIZONTAL

MONITOR
1207
26
1270
71
days
days
0
1
11

SLIDER
492
328
716
361
forage-load
forage-load
0
10
2.0
1
1
NIL
HORIZONTAL

MONITOR
1207
73
1270
118
honey
honey
1
1
11

SLIDER
243
110
467
143
larva-dev-time-mean
larva-dev-time-mean
0
10
7.0
1
1
days
HORIZONTAL

SLIDER
243
145
467
178
larva-dev-time-std
larva-dev-time-std
0
10
2.0
1
1
days
HORIZONTAL

SLIDER
242
181
466
214
pupa-dev-time-mean
pupa-dev-time-mean
0
10
10.0
1
1
days
HORIZONTAL

SLIDER
242
216
466
249
pupa-dev-time-std
pupa-dev-time-std
0
10
3.0
1
1
days
HORIZONTAL

SLIDER
493
220
717
253
max-honey-per-pot
max-honey-per-pot
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
493
255
717
288
min-honey-per-pot
min-honey-per-pot
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
493
290
717
323
flowers-per-forage
flowers-per-forage
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
10
106
234
139
dom-step
dom-step
0
1
0.15
0.01
1
NIL
HORIZONTAL

PLOT
8
473
405
699
Spatial zone signature of different breeds
Days
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Workers" 1.0 0 -4079321 true "" "plotxy ( ticks / 100) zone-sigs workers"
"Queen" 1.0 0 -5825686 true "" "plotxy (ticks / 100) zone-sigs queens"
"Drones" 1.0 0 -11221820 true "" "plotxy (ticks / 100) zone-sigs drones"

PLOT
806
473
1203
699
Bumblebee centrality vs dominance
Distance to centre
Dominance
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "ask (turtle-set workers) [\n  if (length x-coords > 1) and (ticks mod 100 = 0) [\n    plotxy (distancexy 0 0) dom\n  ]\n]"

PLOT
407
473
804
699
Spatial zone signatures per dominance level
Days
Spatial zone signature
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Low-dom" 1.0 0 -2674135 true "" "if count workers > 3 [\n  let low-doms get-dom-group \"low-dom\" \n  if count low-doms > 0\n  [ plotxy days zone-sigs low-doms ]\n]"
"Med-dom" 1.0 0 -1184463 true "" "if count workers > 3 [\n  let med-doms get-dom-group \"med-dom\" \n  if count med-doms > 0\n  [ plotxy days zone-sigs med-doms ]\n]"
"High-dom" 1.0 0 -10899396 true "" "if count workers > 3 [\n  let high-doms get-dom-group \"high-dom\" \n  if count high-doms > 0\n  [ plotxy days zone-sigs high-doms ]\n]"

SWITCH
476
10
662
43
age-dominance
age-dominance
1
1
-1000

TEXTBOX
240
437
717
465
The \"Spatial zone signature\" is a measure of the size of the area a bee moves around in. It is calculated by multiplying the standard deviations of the x and y coordinates.
11
0.0
1

PLOT
8
701
405
927
Time spent in center per dominance level
Days
NIL
0.0
10.0
0.0
0.01
true
true
"" ""
PENS
"Low-dom" 1.0 0 -2674135 true "" "if length time-low-c > 0 [\n  plotxy days smoothing-average time-low-c\n]"
"Med-dom" 1.0 0 -1184463 true "" "if length time-med-c > 0 [\n  plotxy days smoothing-average time-med-c\n]"
"High-dom" 1.0 0 -10899396 true "" "if length time-high-c > 0 [\n  plotxy days smoothing-average time-high-c\n]"

PLOT
407
701
804
927
Time spent in periphery per dominance level
Days
NIL
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"Low-dom" 1.0 0 -2674135 true "" "if length time-low-p > 0 [\n  plotxy days smoothing-average time-low-p\n]"
"Med-dom" 1.0 0 -1184463 true "" "if length time-med-p > 0 [\n  plotxy days smoothing-average time-med-p\n]"
"High-dom" 1.0 0 -10899396 true "" "if length time-high-p > 0 [\n  plotxy days smoothing-average time-high-p\n]"

PLOT
806
701
1203
927
Time spent outside per dominance level
Days
NIL
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"Low-dom" 1.0 0 -2674135 true "" "if length time-low-o > 0 [\n  plotxy days smoothing-average time-low-o\n]"
"Med-dom" 1.0 0 -1184463 true "" "if length time-med-o > 0 [\n  plotxy days smoothing-average time-med-o\n]"
"High-dom" 1.0 0 -10899396 true "" "if length time-high-o > 0 [\n  plotxy days smoothing-average time-high-o\n]"

SLIDER
11
141
233
174
stress-kill-threshold
stress-kill-threshold
0
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
12
177
234
210
stress-fert-threshold
stress-fert-threshold
0
20
1.0
1
1
NIL
HORIZONTAL

PLOT
1205
701
1602
927
Nest composition and development
Days
Individuals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Adults" 1.0 0 -16777216 true "" "plotxy (ticks / 100) count (turtle-set queens workers)"
"Eggs" 1.0 0 -7500403 true "" "plotxy (ticks / 100) count eggs"
"Larvae" 1.0 0 -2674135 true "" "plotxy (ticks / 100) count larvae"
"Pupae" 1.0 0 -955883 true "" "plotxy (ticks / 100) count pupae"
"Drones" 1.0 0 -6459832 true "" "plotxy (ticks / 100) count drones"

PLOT
8
929
405
1079
Low dominance
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Center" 1.0 0 -16777216 true "" "if length time-low-c > 0 [\n  plotxy days smoothing-average time-low-c\n]"
"Periphery" 1.0 0 -7500403 true "" "if length time-low-p > 0 [\n  plotxy days smoothing-average time-low-p\n]"
"Outside" 1.0 0 -2674135 true "" "if length time-low-o > 0 [\n  plotxy days smoothing-average time-low-o\n]"

PLOT
407
929
804
1079
Med dominance
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Center" 1.0 0 -16777216 true "" "if length time-med-c > 0 [\n  plotxy days smoothing-average time-med-c\n]"
"Periphery" 1.0 0 -7500403 true "" "if length time-med-p > 0 [\n  plotxy days smoothing-average time-med-p\n]"
"Outside" 1.0 0 -2674135 true "" "if length time-med-o > 0 [\n  plotxy days smoothing-average time-med-o\n]"

PLOT
806
929
1203
1079
High dominance
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Center" 1.0 0 -16777216 true "" "if length time-high-c > 0 [\n  plotxy days smoothing-average time-high-c\n]"
"Periphery" 1.0 0 -7500403 true "" "if length time-high-p > 0 [\n  plotxy days smoothing-average time-high-p\n]"
"Outside" 1.0 0 -2674135 true "" "if length time-high-o > 0 [\n  plotxy days smoothing-average time-high-o\n]"

SWITCH
477
46
662
79
dominance-behavior?
dominance-behavior?
0
1
-1000

SLIDER
245
320
417
353
smoothing
smoothing
0
300
300.0
1
1
ticks
HORIZONTAL

SLIDER
245
357
456
390
data-time-window
data-time-window
0
10
6.0
1
1
days
HORIZONTAL

SLIDER
246
394
455
427
dom-group-threshold
dom-group-threshold
0
0.3
0.25
0.01
1
NIL
HORIZONTAL

TEXTBOX
93
13
327
43
Parameters from original model
12
0.0
1

TEXTBOX
512
88
716
118
Parameters for 2d-continuous
12
0.0
1

TEXTBOX
255
300
418
330
Plotting/data parameters
12
0.0
1

SLIDER
494
402
707
435
flee-distance
flee-distance
0
20
7.0
1
1
patches
HORIZONTAL

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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Compare Dominance per Region" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7000"/>
    <metric>plot-dominance-groups "c" "low" 0.25</metric>
    <metric>plot-dominance-groups "c" "med" 0.25</metric>
    <metric>plot-dominance-groups "c" "high" 0.25</metric>
    <metric>plot-dominance-groups "p" "low" 0.25</metric>
    <metric>plot-dominance-groups "p" "med" 0.25</metric>
    <metric>plot-dominance-groups "p" "high" 0.25</metric>
    <metric>plot-dominance-groups "o" "low" 0.25</metric>
    <metric>plot-dominance-groups "o" "med" 0.25</metric>
    <metric>plot-dominance-groups "o" "high" 0.25</metric>
    <enumeratedValueSet variable="dom-step">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="digest-rate">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="larva-dev-time-mean">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dominance-behavior?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pupa-dev-time-mean">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="oviposit-time">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flowers-per-forage">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="larva-dev-time-std">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stress-fert-threshold">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pupa-dev-time-std">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-honey-per-pot">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="honeypot-max-dist">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-honey-per-pot">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queen-dom-init">
      <value value="7.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stress-kill-threshold">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-dominance">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-dist-egg-egg">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="egg-hatch-time-std">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="worker-dom-init">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dominance-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-dist-honey-egg">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="egg-hatch-time-mean">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forage-load">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
