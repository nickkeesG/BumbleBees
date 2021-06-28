globals [
  days
  honey

  avg-low-c
  avg-med-c
  avg-high-c
  avg-low-p
  avg-med-p
  avg-high-p
  avg-low-o
  avg-med-o
  avg-high-o
]

patches-own [
  region
  honeypot?
  egg-here?
  dev-here?
]

turtles-own [
  dom
  age
  food
  target
  busy?
  task
  in-flight?
  dev-time
  ovi-wait-time
  flowers-visited
  x-coords
  y-coords
  time-center
  time-periphery
  time-outside
  discount-time-center
  discount-time-periphery
  discount-time-outside
  stress
  sex
  rand-id ;; a random id which does not relate to when a turtle is born
]

breed [queens queen]
breed [newQueens newQueen]
breed [pupae pupa]
breed [workers worker]
breed [drones drone]
breed [larvae larva]
breed [eggs egg]

to data.config
  set x-coords []
  set y-coords []
  set time-center 0
  set time-periphery 0
  set time-outside 0
  set discount-time-center (1 / 3)
  set discount-time-periphery (1 / 3)
  set discount-time-outside (1 / 3)
end

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
  data.config
end

to worker.config
  set dom worker-dom-init
  set color orange
  set age 0
  set in-flight? False
  set size 1.5
  set task "no-task"
  data.config
  set rand-id random 10000
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
  data.config
end

;;SETUP METHODS
to setup
  clear-all
  set days 0
  set honey 10
  ask patches [ setup-patch ]
  create-queens 1 [ queen.config ]
  reset-ticks
end

to setup-patch
  set honeypot? False
  set egg-here? False
  set dev-here? False

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

  if (pxcor = 0) and (pycor = 0) [
    set honeypot? True
    set pcolor yellow
  ]
end

;;ALL OTHER METHODS
to go
  ask (turtle-set queens workers drones) [
    select-task
    if busy? [
      ifelse patch-here = target [
        finish-task
      ]
      [
        let speed-mod min list dom 1
        ifelse in-flight? [
          fd 1 * speed-mod
        ]
        [
          fd 0.2 * speed-mod
        ]
      ]
    ]
    ; record time spent in a region
    if [region] of patch-here = "center" [ set time-center time-center + 1]
    if [region] of patch-here = "periphery" [ set time-periphery time-periphery + 1]
    if [region] of patch-here = "outside" [ set time-outside time-outside + 1]

    ; update time spent in a region
    let discount-factor 0.999
    set discount-time-center (discount-time-center * discount-factor)
    set discount-time-periphery (discount-time-periphery * discount-factor)
    set discount-time-outside (discount-time-outside * discount-factor)
    if [region] of patch-here = "center" [ set discount-time-center discount-time-center + (1 - discount-factor)]
    if [region] of patch-here = "periphery" [ set discount-time-periphery discount-time-periphery + (1 - discount-factor)]
    if [region] of patch-here = "outside" [ set discount-time-outside discount-time-outside + (1 - discount-factor)]
  ]
  ask (turtle-set queens newQueens workers drones) [
    if [region] of patch-at xcor ycor != "outside" [
      ; save x and y coords for calculation of SD
      set x-coords fput xcor x-coords
      set y-coords fput ycor y-coords
    ]
  ]
  ask eggs [
    if age >= dev-time [
      ask patch-here [
        set egg-here? False
        set dev-here? True
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
      ask patch-here [set dev-here? False]
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

  increment-model-time
end

to select-task
  if is-queen? self or is-worker? self [
    if not busy? [
      eat-honey
    ]
    if not busy? [
      build-honeypot
    ]
    if not busy? [
      forage
    ]
    if not busy? [
      lay-egg
    ]
    if not busy? [
      if dominance-behavior? [
        dominate
      ]
    ]
  ]
  if not busy? [
    no-task
  ]
end

to eat-honey
  if food <= 0 [
    set target min-one-of patches with [honeypot?] [distance myself]
    set heading towards target
    set busy? True
    set task "eat-honey"
  ]
end

to build-honeypot
  if count turtles with [task = "build-honeypot"] = 0 [
    if (get-expected-honey / count patches with [honeypot?]) > max-honey-per-pot [
      let target-pot one-of patches with [honeypot?]
      set target one-of patches with [distance target-pot <= honeypot-max-dist
      and not (honeypot? or egg-here? or dev-here?)]
      if not (target = NOBODY) [
        set heading towards target
        set busy? True
        set task "build-honeypot"
      ]
    ]
  ]
end

to-report get-expected-honey
  report (honey + (forage-load * (count (turtles-on patches with [not (region = "outside")])
    with [task = "forage" or task = "return"])))
end

to forage
  if (get-expected-honey / count patches with [honeypot?]) < min-honey-per-pot [
    set target one-of patches with [region = "outside"]
    set heading towards target
    set busy? True
    set in-flight? True
    set task "forage"
    set flowers-visited 0
  ]
end

to flee [other-bee]
  set heading towards other-bee
  rt 180
  set target one-of patches in-cone 10 20 with [distance myself > 8]
  set heading towards target
  set task "flee"
  set color violet
  set busy? True
end

to lay-egg
  if (is-queen? self) and ovi-wait-time <= 0 [
    let target-egg patch 0 0
    if count patches with [egg-here?] > 0 [
      set target-egg one-of patches with [egg-here?]
    ]

    set target one-of (patches with [distance target-egg <= max-dist-egg-egg and
      distance (min-one-of patches with [honeypot?] [distance self]) <= max-dist-honey-egg
      and not honeypot? and not egg-here? and not dev-here?])

    if not (target = NOBODY) [
      set heading towards target
      set busy? True
      set task "lay-egg"
    ]
  ]
end

to dominate
  let nearest-bee min-one-of other (turtle-set queens workers) with [not in-flight?] [distance myself]
  if (not (nearest-bee = NOBODY)) and (distance nearest-bee <= dominance-radius) [
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

    if ((is-queen? self) and (task = "lay-egg") and (target = patch-here))
      [ ifelse (k = 1) [set stress stress + 1] [set stress stress + 2]]
    if ((is-queen? nearest-bee) and ([(task = "lay-egg") and (target = patch-here)] of nearest-bee = True)) [ ifelse (k = 1)
      [ask nearest-bee [set stress stress + 1]] [ ask nearest-bee [set stress stress + 2]]]

    ifelse k = 1 [
      ask nearest-bee [ flee myself ]
    ]
    [
      flee nearest-bee
    ]
  ]
end

to no-task
  set task "no-task"
  set target one-of patches with [not (region = "outside") and (distance myself < 4)]
  if target = NOBODY [ set target min-one-of patches with [not (region = "outside")] [distance myself]]
  set heading towards target
  set busy? True
end

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
      set target one-of patches with [honeypot?]
      set heading towards target
    ]
    [
      set target one-of patches with [region = "outside" and (distance myself < 5)]
      if target = NOBODY [ set target one-of patches with [region = "outside"] ]
      set heading towards target
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
  ask workers [
    if age > 28 [
      die
    ]
  ]
  ask queens [ if stress > stress-kill-threshold [die] ]
  tick
end

; Reporting and statistics functions

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

to-report zone-sigs [ _breed ] ;; agent set method
  let relevant-agents (turtle-set _breed) with [ length x-coords > 1 ]
  ifelse count relevant-agents > 0
  [
    report mean [ zone-sig self ] of relevant-agents
  ]
  [
    report 0
  ]

end

to-report centroid [ _turtle ] ;; turtle method
  if length x-coords > 0 [
    let x-centroid sum x-coords / length x-coords
    let y-centroid sum y-coords / length y-coords
  ]
end

to-report calculate-centroids [ _breed ] ;; agent set method
  let relevant-agents (turtle-set _breed) with [ length x-coords > 1 ]
  if count relevant-agents > 0 [
    let x-centroid mean ( map [ x -> sum x / length x ] [ x-coords] of _breed  )
    let y-centroid mean ( map [ y -> sum y / length y ] [ y-coords] of _breed  )
    report list x-centroid y-centroid
  ]
  ; can i just not report anything if i don't want to?

end

to check-var-dominance-interaction [ var min-sd max-sd ]
  ;; plotting function
  ;; negative values represent infinity
  ;; var: represents which time spent should be plotted, "c" = center, "p" = periphery, "o" = outside
  ;; min-sd and max-sd are the sd offsets from the average, e.g. check-var-dominance-interaction "c" 0.5 0.5 will check [-0.5sd, 0.5sd)
  ;; setting either to a negative value will mean that that boundary is interpreted as infinity

  ifelse count workers > 1
  [
    let dom-sd standard-deviation [ dom ] of workers
    let dom-avg mean [ dom ] of workers

    ; find the relevant workers for the plot
    let rel-workers no-turtles

    if min-sd >= 0 and max-sd < 0 [
      ; everything below a given sd
      set rel-workers (workers with [ dom < (dom-avg - min-sd * dom-sd) ])
    ]
    if min-sd < 0 and max-sd >= 0 [
      ; everything above a given sd
      set rel-workers (workers with [ dom >= (dom-avg + max-sd * dom-sd) ])
    ]
    if min-sd >= 0 and max-sd >= 0 [
      ; everything inbetween some sds
      set rel-workers (workers with [ dom > (dom-avg - min-sd * dom-sd) and dom <= (dom-avg + max-sd * dom-sd) ])
    ]

    ifelse count rel-workers > 0
    [
      let relative-var (ifelse-value
        var = "c" [ [ time-center / (age * 100) ] of rel-workers ]
        var = "p" [ [ time-periphery / (age * 100) ] of rel-workers ]
        var = "o" [ [ time-outside / (age * 100) ] of rel-workers ]
                  [ [ time-center / (age * 100) ] of rel-workers ])
      plotxy (ticks / 100) mean relative-var
    ]
    [
      ;;plot 0
    ]
  ]
  [
    ;;plot 0
  ]
end

to-report plot-dominance-groups [ var group-name fraction]
  ;; plotting function
  ;; all agents are by default in group "medium" unless they fall in the top (or bottom) fraction of dominance
  ;; var is the variable being plotted

  if count workers >= 3
  [
    let agent-group workers
    let sorted-workers sort-on [ rand-id ] workers
    if dominance-behavior? [
      set sorted-workers sort-on [ dom ] workers
    ]
    let med-idx floor (2 + (length sorted-workers * fraction))

    let lowset sublist sorted-workers 1 med-idx
    let lows workers with [member? self lowset]

    let flipped-workers reverse sorted-workers
    let highset sublist flipped-workers 1 med-idx
    let highs workers with [member? self highset]

    let meds workers with [not (member? self lowset) and not (member? self highset)]

    if group-name = "low"[
      set agent-group lows
    ]
    if group-name = "med" [
      set agent-group meds
    ]
    if group-name = "high" [
      set agent-group highs
    ]

    let time-list (ifelse-value
        var = "c" [ [ discount-time-center ] of agent-group ]
        var = "p" [ [ discount-time-periphery ] of agent-group ]
        var = "o" [ [ discount-time-outside ] of agent-group ]
                  [ [ discount-time-center ] of agent-group ])
    report mean time-list
  ]
    report "no-plot"
end

to smooth-plot [ var group-name fraction]
  let discount 0.98

  let value plot-dominance-groups var group-name fraction
  if not (value = "no-plot") [
  if var = "c" [
    if group-name = "low" [
      set avg-low-c (avg-low-c * discount)
      set avg-low-c avg-low-c + (value * (1 - discount))
      plotxy (ticks / 100) avg-low-c
    ]
    if group-name = "med" [
      set avg-med-c (avg-med-c * discount)
      set avg-med-c avg-med-c + (value * (1 - discount))
      plotxy (ticks / 100) avg-med-c
    ]
    if group-name = "high" [
      set avg-high-c (avg-high-c * discount)
      set avg-high-c avg-high-c + (value * (1 - discount))
      plotxy (ticks / 100) avg-high-c
    ]
  ]
  if var = "p" [
    if group-name = "low" [
      set avg-low-p (avg-low-p * discount)
      set avg-low-p avg-low-p + (value * (1 - discount))
      plotxy (ticks / 100) avg-low-p
    ]
    if group-name = "med" [
      set avg-med-p (avg-med-p * discount)
      set avg-med-p avg-med-p + (value * (1 - discount))
      plotxy (ticks / 100) avg-med-p
    ]
    if group-name = "high" [
      set avg-high-p (avg-high-p * discount)
      set avg-high-p avg-high-p + (value * (1 - discount))
      plotxy (ticks / 100) avg-high-p
    ]
  ]
  if var = "o" [
    if group-name = "low" [
      set avg-low-o (avg-low-o * discount)
      set avg-low-o avg-low-o + (value * (1 - discount))
      plotxy (ticks / 100) avg-low-o
    ]
    if group-name = "med" [
      set avg-med-o (avg-med-o * discount)
      set avg-med-o avg-med-o + (value * (1 - discount))
      plotxy (ticks / 100) avg-med-o
    ]
    if group-name = "high" [
      set avg-high-o (avg-high-o * discount)
      set avg-high-o avg-high-o + (value * (1 - discount))
      plotxy (ticks / 100) avg-high-o
    ]
  ]
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
8
10
232
43
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
8
45
232
78
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
8
80
232
113
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
8
115
232
148
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
8
150
232
183
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
8
185
232
218
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
8
220
232
253
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
8
255
232
288
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
8
325
232
358
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
8
290
232
323
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
673
88
736
133
days
days
0
1
11

SLIDER
8
360
232
393
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
673
135
736
180
honey
honey
1
1
11

SLIDER
8
395
232
428
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
8
430
232
463
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
10
466
43
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
45
466
78
pupa-dev-time-std
pupa-dev-time-std
0
10
2.0
1
1
days
HORIZONTAL

SLIDER
242
80
466
113
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
242
115
466
148
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
242
150
466
183
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
242
185
466
218
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
"Low (< -.5σ)" 1.0 0 -2674135 true "" "if count workers > 1\n[\nlet dom-sd standard-deviation [ dom ] of workers\nlet dom-avg mean [ dom ] of workers\n\nlet low-workers (workers with [ dom < (dom-avg - 1 * dom-sd) ]) \nif count low-workers > 0\n[ plotxy (ticks / 100) zone-sigs low-workers ]\n]"
"Med [-.5σ, +.5σ)" 1.0 0 -1184463 true "" "if count workers > 1 [\nlet dom-sd standard-deviation [ dom ] of workers\nlet dom-avg mean [ dom ] of workers\n\nlet med-workers (workers with [ dom >= (dom-avg - 1 * dom-sd ) and dom < (dom-avg + 1 * dom-sd) ]) \nif count med-workers > 0\n[ plotxy (ticks / 100) zone-sigs med-workers ]\n]"
"High (> +.5σ)" 1.0 0 -10899396 true "" "if count workers > 1 [\nlet dom-sd standard-deviation [ dom ] of workers\nlet dom-avg mean [ dom ] of workers\n\nlet high-workers (workers with [ dom >= (dom-avg + 1 * dom-sd ) ])\nif count high-workers > 0 \n[ plotxy (ticks / 100) zone-sigs high-workers ]\n]"

SWITCH
476
10
619
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
"Low" 1.0 0 -2674135 true "" "smooth-plot \"c\" \"low\" 0.25"
"Med" 1.0 0 -1184463 true "" "smooth-plot \"c\" \"med\" 0.25\n"
"High" 1.0 0 -10899396 true "" "smooth-plot \"c\" \"high\" 0.25"

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
"Low" 1.0 0 -2674135 true "" "smooth-plot \"p\" \"low\" 0.25"
"Med " 1.0 0 -1184463 true "" "smooth-plot \"p\" \"med\" 0.25"
"High" 1.0 0 -10899396 true "" "smooth-plot \"p\" \"high\" 0.25"

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
"Low" 1.0 0 -2674135 true "" "smooth-plot \"o\" \"low\" 0.25"
"Med" 1.0 0 -1184463 true "" "smooth-plot \"o\" \"med\" 0.25"
"High" 1.0 0 -10899396 true "" "smooth-plot \"o\" \"high\" 0.25"

SLIDER
243
220
465
253
stress-kill-threshold
stress-kill-threshold
0
20
15.0
1
1
NIL
HORIZONTAL

SLIDER
244
256
466
289
stress-fert-threshold
stress-fert-threshold
0
20
5.0
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

SWITCH
477
46
662
79
dominance-behavior?
dominance-behavior?
1
1
-1000

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
