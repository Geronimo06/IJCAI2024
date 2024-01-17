;;------------------------------------------------------------------------------------------------------------------
;; AGENT-BASED MODELLING OF ON-STREET ELECTRIC CARS AND PUBLIC CHARGING STATIONS
;;------------------------------------------------------------------------------------------------------------------
;; The city is full of identical 50x50 metres building blocks
;; 1 patch = 5 x 5 metres, so one block = 10x10 patches
;; charging stations are on the edge of the building blocks
;; a charging station is a square of 5 x 5 metres and 1 station = 1 patch = 5 metres
;; a street is a vertical or horizontal alignment of patches between blocks
;; A crossroad is a patch at the intersection of 4 streets
;; the distance between 2 consecutive crossroads is 50 metres
;; between two crossroads there are potentialy 8 stations (you can't charge on the 4 corner of two streets)
;
; All electric car move on street at the same speed:
;; each car travels 1  patch   during 1  tick  (that is 5 metres)
;; each car travels 10 patches during 10 ticks (that is the distance of 50 metres between 2 consecutive crossroads)
;; it is assumed that all the cars move at the same speed
;
;; --------------- e-car states
;; [1]   "DRIVING_ON_STREET"    (Initial state)
;; [2]   "SEARCHING_STATION"
;; [3]   "REACHING_STATION"
;; [4]   "CHARGING"
;; [5]   "OUT_OF_SERVICE"       (final state)
;;
;; --------------- e-car state transitions
;; [1] -> [2]
;; [2] -> [3] or [5]
;; [3] -> [4] or [5]
;; [4] -> [1]
;; --------------- c-station states
;; [1]   "AVAILABLE"     (Initial state)
;; [2]   "NOT_AVAILABLE"
;; --------------- c-station transitions
;; [1] -> [2]
;; [2] -> [1]
;;------------------------------------------------------------------------------------------------------------------
breed [ e-cars     e-car     ] ;; --------------- electric cars
breed [ c-stations c-station ] ;; --------------- charging stations
;;------------------------------------------------------------------------------------------------------------------

globals [
  #passage-on-5-0                  ; number of vehicles passing on patch 5 0
  size-bloc-building
  #second-per-tick                 ; number of second per ticks
  ;; ----------
  ; A/B-ratio                      ; slider: if (partition of the population of cars/drivers in two parts A and B) the ratio A / B
  ;; ----------
  ; #e-cars                        ; slider: number of electric cars
  ; car-speed                      ; slider: car speed in km-per-hour
  ; car-range-in-km                ; slider: e-car range in kilometers
  car-range-in-min                 ; maximum moving time with a full battery in minutes
  car-range-in-ticks               ; maximum moving time with a full battery in ticks
  ;; ----------
  ; station/car-ratio              ; slider: (#c-stations / #e-cars)
  ;; ----------
  #c-stations                      ; number of public charging stations
  ; charging-time-in-min           ; slider: maximum time required to recharge the battery at a c-station in minutes (i.e. to charge the battery from 0% to 100% of its capacity)
  charging-time-in-ticks           ; maximum time required to recharge the battery at a c-station in ticks
  ; global-car-range-ratio-threshold      ; slider: ratio of the maximum moving-time (car-range) beyond which one e-car moving-on-street searches for one c-station
  ;; --------------- patches AGENTS-SET
  the-streets
  the-crossroads
  the-parking-spots
  ;; --------------- ENVIRONMENT COLOR
  color-building
  color-street
  color-crossroad
  color-parking-spot
  ;; --------------- e-cars COLOR
  color-car-DRIVING_ON_STREET
  color-car-SEARCHING_STATION
  color-car-REACHING_STATION
  color-car-CHARGING
  color-car-OUT_OF_SERVICE
  ;; --------------- c-stations COLOR
  color-station-AVAILABLE
  color-station-NOT_AVAILABLE
  ;; --------------- e-cars SHAPE
  shape-car-DRIVING_ON_STREET
  shape-car-SEARCHING_STATION
  shape-car-REACHING_STATION
  shape-car-CHARGING
  shape-car-OUT_OF_SERVICE
  ;; --------------- c-stations SHAPE
  shape-station-AVAILABLE
  shape-station-NOT_AVAILABLE
] ;; end globals

;;------------------------------------------------------------------------------------------------------------------
e-cars-own [
  c-state                         ; "DRIVING_ON_STREET" or "SEARCHING_STATION" or "REACHING_STATION" or "CHARGING" or "OUT_OF_SERVICE"
  current-moving-time-in-ticks    ; current time on-street (in states [1], [2], [3])
  current-ratio-capacity-consumed ; ratio of the maximum available battery capacity already consumed  (in states [1], [2], [3])
  current-charging-time-in-ticks  ; current time in state "CHARGING"
  target-station                  ; the c-station where to recharge the battery
  return-location                 ; the location on-street to return after recharging the battery at a station
  car-range-ratio-threshold       ; ratio of the maximum moving-time (car-range) beyond which one e-car moving-on-street searches for one c-station
  #chargings                      ; number of battery charges
] ;; end e-cars-own

;;------------------------------------------------------------------------------------------------------------------
c-stations-own [
  s-state                         ; "AVAILABLE" or "NOT_AVAILABLE"
  ;affected-car                   ; the electric car that booked the station
] ;; end c-stations-own

;;------------------------------------------------------------------------------------------------------------------
;; INITIALISATION
;;------------------------------------------------------------------------------------------------------------------
to startup
  set #e-cars                     1000
  set car-speed-in-km-h           25    ; km/h
  set car-range-in-km             300   ; km
  set charging-time-in-min        60    ; min
end ; startup

;;------------------------------------------------------------------------------------------------------------------
to setup
  clear-all
  ;; one building is 10x10 patches (i.e. 50x50 metres)
  set size-bloc-building          10 ;; with origne corner, max-pxcor=98,  max-pycor=98
  ;; ----------
  set #second-per-tick            (5 * 3600) / (1000 * car-speed-in-km-h) ;; (1.8, 0.9, 0.6) secondes for (10, 20, 30) km/h
  let #minute-per-tick            (#second-per-tick / 60                  )
  set car-range-in-min            (60 * (car-range-in-km / car-speed-in-km-h))
  set charging-time-in-ticks      (charging-time-in-min  / #minute-per-tick  )
  set car-range-in-ticks          (car-range-in-min      / #minute-per-tick  )
  ;; ----------
  setup-colors
  setup-shapes
  ;; ----------
  setup-the-streets
  setup-the-crossroads
  setup-the-parking-spots
  ;; ----------
  setup-the-cars
  setup-the-stations
  ;; ----------
  reset-ticks ; ticks <- 0
end ;; setup

;;------------------------------------------------------------------------------------------------------------------
to setup-colors
  ;; ----- environment color -----
  set color-building                      grey  + 1
  ask patches [set pcolor color-building]
  set color-street                        white
  set color-crossroad                     pink  + 1
  set color-parking-spot                  grey  + 1
  ;; ----- e-cars color -----
  set color-car-DRIVING_ON_STREET         blue
  set color-car-SEARCHING_STATION         green
  set color-car-REACHING_STATION          pink
  set color-car-CHARGING                  red
  set color-car-OUT_OF_SERVICE            black
  ;; ----- c-stations color -----
  set color-station-AVAILABLE             green
  set color-station-NOT_AVAILABLE         red
end ;; setup-colors

;;------------------------------------------------------------------------------------------------------------------
to setup-shapes ;; shape depends on state
  ;; ----- e-cars shape -----
  set shape-car-DRIVING_ON_STREET        "car"
  set shape-car-SEARCHING_STATION        "car"
  set shape-car-REACHING_STATION         "car"
  set shape-car-CHARGING                 "car"
  set shape-car-OUT_OF_SERVICE           "triangle"
  ;; ----- c-stations shape -----
  set shape-station-AVAILABLE            "target"
  set shape-station-NOT_AVAILABLE        "X"
end ;; setup-shapes

;;------------------------------------------------------------------------------------------------------------------
to setup-the-streets ;; based on the "Manhattan city model" the streets are horizontal or vertical alignments of patches
  set the-streets patches with [ pxcor mod (size-bloc-building + 1) = 0 or  pycor mod (size-bloc-building + 1) = 0 ]
  ask the-streets [ set pcolor color-street ]
end ;; setup-the-streets

;;------------------------------------------------------------------------------------------------------------------
to setup-the-crossroads ;; a crossroad is a patch at the intersection of 4 streets
  set the-crossroads patches with [pxcor mod (size-bloc-building + 1) = 0 and pycor mod (size-bloc-building + 1) = 0]
  ask the-crossroads [ set pcolor color-crossroad ]
end ;; setup-the-crossroads

;;------------------------------------------------------------------------------------------------------------------
to setup-the-parking-spots ;; a parking-spot is a patch at the edge of the building areas where a public charging station could be positioned
  set the-parking-spots patches  with [ (pxcor + 1) mod (size-bloc-building + 1) = 0 or (pycor + 1) mod (size-bloc-building + 1) = 0 or
                                        (pxcor - 1) mod (size-bloc-building + 1) = 0 or (pycor - 1) mod (size-bloc-building + 1) = 0 ]
  set the-parking-spots the-parking-spots with [ not (pxcor mod (size-bloc-building + 1) = 0 or  pycor mod (size-bloc-building + 1) = 0) ]
  ;; exclude charging stations in the immediate vicinity of a crossroad
  set the-parking-spots the-parking-spots with [ count neighbors4 with [ pcolor = color-street ] = 1 ]
  ask the-parking-spots [ set pcolor color-parking-spot ]
end ;; setup-the-parking-spots

;;------------------------------------------------------------------------------------------------------------------
to setup-the-cars ;; e-cars are mobile turtles on the streets
  ;; the number of cars (#e-cars) is fixed by a slider
  ;; create the cars on the streets with random locations
  ask n-of #e-cars the-streets [ ;; no more than one car per street location
      sprout-e-cars 1 [
        update-car "DRIVING_ON_STREET" ;; initially a car moves on-street
        set size        1.4
        set #chargings  0
        ;; fixe the heading in orded to move on-street
        ifelse ([pcolor] of patch-at 0 1 = color-street or [pcolor] of patch-at 0 1 = color-crossroad)
        [ ifelse (random-float 1 < 0.5) [ set heading 0  ] [ set heading 180 ]]
        [ ifelse (random-float 1 < 0.5) [ set heading 90 ] [ set heading 270 ]]
     ]
  ]
  ;; set the initial current-moving-time-in-ticks at random, then 0 as soon the car is again in state "DRIVING_ON_STREET"
  ;; Experience 1
  if (EXPERIENCE = "exp1") [ ask e-cars [set car-range-ratio-threshold global-car-range-ratio-threshold ] ]
  ;; Experience 2 (two groups with .3 et .7 respectivley and V1-ratio=.5)
  if (EXPERIENCE = "exp2") [
      ask e-cars                      [ set car-range-ratio-threshold 0.7 ]
      ask n-of (.5 * #e-cars) e-cars  [ set car-range-ratio-threshold 0.3 ]
  ]
  ;; Experience 4 (two groups with .3 et .7 respectively and V1-ratio=.1)
  if (EXPERIENCE = "exp4") [
      ask e-cars                      [ set car-range-ratio-threshold 0.7 ]
      ask n-of (.1 * #e-cars) e-cars  [ set car-range-ratio-threshold 0.3 ]
  ]
  ;; Experience 5 (two groups with .3 et .7 respectively and V1-ratio=.9)
  if (EXPERIENCE = "exp5") [
      ask e-cars                      [ set car-range-ratio-threshold 0.3 ]
      ask n-of (.1 * #e-cars) e-cars  [ set car-range-ratio-threshold 0.7 ]
  ]
  ;
  ask e-cars [ set current-moving-time-in-ticks (car-range-in-ticks * (random-float (car-range-ratio-threshold))) ]
end ;; setup-the-cars

;;------------------------------------------------------------------------------------------------------------------
to setup-the-stations ;; public charging stations are motionless turtles on some parking-spots
  set #c-stations (#e-cars * (1 / car/station-ratio))
  ;; create the charging stations on the parking-spots with random location
  ask n-of #c-stations the-parking-spots [ ;; no more than one station per edge location
      sprout-c-stations 1 [
         update-station "AVAILABLE"
         set size       1.8
      ]
  ]
end ;; setup-the-stations

;;------------------------------------------------------------------------------------------------------------------
;;------------------------------------------------------------------------------------------------------------------
;; MAIN PROCEDURE
;;------------------------------------------------------------------------------------------------------------------
;;------------------------------------------------------------------------------------------------------------------
to go
  ask e-cars
  [ if (patch-here = patch 5 0) [set #passage-on-5-0  (#passage-on-5-0  + 1)]
    ;;  to ensure that a car changes its state no more than once in the go procedure
    let case ( ifelse-value
      c-state = "DRIVING_ON_STREET"     [ "DRIVING_ON_STREET" ]
      c-state = "SEARCHING_STATION"     [ "SEARCHING_STATION" ]
      c-state = "REACHING_STATION"      [ "REACHING_STATION"  ]
      c-state = "CHARGING"              [ "CHARGING"          ]
      c-state = "OUT_OF_SERVICE"        [ "OUT_OF_SERVICE"    ]
    )
    ;; ----------
    if (case = "DRIVING_ON_STREET")
    [ set current-ratio-capacity-consumed (current-moving-time-in-ticks / car-range-in-ticks)
      ifelse (car-range-ratio-threshold <= current-ratio-capacity-consumed)
      [ ; the threshold is exceeded
        transition-to "SEARCHING_STATION"
      ]
      [ ; else the car remains in state "DRIVING_ON_STREET"
        forward-one-step-at-random
      ]
    ]
    ;; ----------
    if (case = "SEARCHING_STATION")
    [ ; look for a charging station
      ifelse (mobile-app-to-find-EV-charging-stations? = true)
      [ ; mobile-app: search for the nearest available station
        set target-station min-one-of (c-stations with [(s-state = "AVAILABLE")]) [distance myself]
      ]
      [ ; else, no mobile-app: taking proximity into account
        set target-station min-one-of (c-stations with [(s-state = "AVAILABLE") and (distance myself < (size-bloc-building / 2))]) [distance myself]
      ]
      ifelse (target-station != nobody)
      [ ; there is a suitable station
        transition-to "REACHING_STATION"
      ]
      [ ; else no suitable station available
        set current-ratio-capacity-consumed (current-moving-time-in-ticks / car-range-in-ticks)
        ifelse (1 <= current-ratio-capacity-consumed)
        [ ; the battery is empty and the car becomes "out of service" (i.e. stops)
          transition-to "OUT_OF_SERVICE"
        ]
        [ ; else the battery is not empty and the car moves again on street in state "SEARCHING_STATION"
          forward-one-step-at-random
        ]
      ]
    ]
    ;; ----------
    if (case = "REACHING_STATION")
    [ ifelse (distance target-station > 1)
      [ ; the car is not yet close to the target station
        set current-ratio-capacity-consumed (current-moving-time-in-ticks / car-range-in-ticks)
        ifelse (1 <= current-ratio-capacity-consumed)
        [ ; the battery is empty and the car becomes "out of service" (i.e. stops)
          transition-to "OUT_OF_SERVICE"
        ]
        [ ; else the battery is not empty and the car move again to the target station in state "REACHING_STATION"
          forward-one-step-to-target-station
        ]
      ]
      [ ; else the car is close to the target
        transition-to "CHARGING"
      ]
    ]
    ;; ----------
    if (case = "CHARGING")
    [ ; checking the battery charge
      ifelse (charging-time-in-ticks <= current-charging-time-in-ticks)
      [ ; the battery is fully charged
        transition-to "DRIVING_ON_STREET"
      ]
      [ ; else the battery is not yet fully charged and the car remains motionless in state "CHARGING"
        set current-charging-time-in-ticks (current-charging-time-in-ticks + 1)
      ]
    ]
    ;; ----------
    if (case = "OUT_OF_SERVICE")
    [ ; final state: do nothing
    ]
  ] ; end ask the e-cars
  tick ;; ticks <- (ticks + 1)
  if (ticks > 1000000) [beep stop]
end ;; go

;;------------------------------------------------------------------------------------------------------------------
to transition-to [new-state]
  ;; ---------- Transition from "DRIVING_ON_STREET" to "SEARCHING_STATION"
  if (new-state = "SEARCHING_STATION") [
    if (c-state != "DRIVING_ON_STREET") [ error-code 1 ]
    update-car new-state
  ]
  ;; ---------- Transition from SEARCHING_STATION" to "REACHING_STATION"
  if (new-state = "REACHING_STATION") [
    if (c-state != "SEARCHING_STATION") [ error-code 2 ]
    ask target-station [ update-station "NOT_AVAILABLE" ]
    update-car new-state
  ]
  ;; ---------- Transition from "SEARCHING_STATION" or "REACHING_STATION" to "OUT_OF_SERVICE"
  if (new-state = "OUT_OF_SERVICE") [
    if (c-state != "SEARCHING_STATION" and c-state != "REACHING_STATION") [ error-code 3]
    update-car new-state
  ]
  ;; ---------- Transition from REACHING_STATION" to "CHARGING"
  if (new-state = "CHARGING") [
    if (c-state != "REACHING_STATION") [ error-code 4 ]
    set return-location patch-here ;; to be able to return on street after recharging the battery
    set current-ratio-capacity-consumed (current-moving-time-in-ticks / car-range-in-ticks) ;; take into account the remaining capacity of the battery
    set current-charging-time-in-ticks (charging-time-in-ticks * (1 - current-ratio-capacity-consumed))
    move-to target-station
    set #chargings  (#chargings + 1)
    update-car new-state
  ]
  ;; ---------- Transition from "CHARGING" to "DRIVING_ON_STREET"
  if (new-state = "DRIVING_ON_STREET") [
    if (c-state != "CHARGING") [ error-code 5 ]
    update-car new-state
    ;; return on street
    move-to return-location
    set current-moving-time-in-ticks 0
    ask target-station [ update-station "AVAILABLE" ]
  ]
end ;; transition-to

;;------------------------------------------------------------------------------------------------------------------
to forward-one-step-at-random
  if (pcolor = color-crossroad) [ ;; the car is on a crossroad
     ;; choose at random one of the 4 East-West-North-South-directions (so the car turns around the Manhattan streets)
     let next-position one-of neighbors4
     set heading (ifelse-value ;; heading in degrees
        next-position = patch-at  1  0 [ 90  ]
        next-position = patch-at -1  0 [ 270 ]
        next-position = patch-at  0 -1 [ 180 ]
        next-position = patch-at  0  1 [ 0   ]
     )
  ]
  ;; ---------- in all cases the car moves forward 1 step
  fd 1
  set current-moving-time-in-ticks (current-moving-time-in-ticks + 1)
end ;; forward-one-step-at-random

;;------------------------------------------------------------------------------------------------------------------
to forward-one-step-to-target-station
  if (pcolor = color-crossroad) [ ;; the car is on a crossroad
     ;; choose the 4 East-West-North-South-directions closest to the target
     let the-target target-station
     let next-location min-one-of neighbors4 [distance the-target]
     set heading (ifelse-value ;; heading is in degrees
        next-location = patch-at  1  0 [ 90  ]
        next-location = patch-at -1  0 [ 270 ]
        next-location = patch-at  0 -1 [ 180 ]
        next-location = patch-at  0  1 [ 0   ]
     )
  ]
  ;; ---------- in all cases the car moves forward 1 step
  fd 1
  set current-moving-time-in-ticks (current-moving-time-in-ticks + 1)
end ;; forward-one-step-to-target-station

;;------------------------------------------------------------------------------------------------------------------
to update-car [new-state]
  set c-state new-state
  set color (ifelse-value
    c-state = "DRIVING_ON_STREET"   [ color-car-DRIVING_ON_STREET ]
    c-state = "SEARCHING_STATION"   [ color-car-SEARCHING_STATION ]
    c-state = "REACHING_STATION"    [ color-car-REACHING_STATION  ]
    c-state = "CHARGING"            [ color-car-CHARGING          ]
    c-state = "OUT_OF_SERVICE"      [ color-car-OUT_OF_SERVICE    ]
  )
  set shape (ifelse-value
    c-state = "DRIVING_ON_STREET"   [ shape-car-DRIVING_ON_STREET ]
    c-state = "SEARCHING_STATION"   [ shape-car-SEARCHING_STATION ]
    c-state = "REACHING_STATION"    [ shape-car-REACHING_STATION  ]
    c-state = "CHARGING"            [ shape-car-CHARGING          ]
    c-state = "OUT_OF_SERVICE"      [ shape-car-OUT_OF_SERVICE    ]
  )
end ;; update-car

;;------------------------------------------------------------------------------------------------------------------
to update-station [new-state]
  set s-state new-state
  set color (ifelse-value
    s-state = "AVAILABLE"            [ color-station-AVAILABLE     ]
    s-state = "NOT_AVAILABLE"        [ color-station-NOT_AVAILABLE ]
  )
  set shape (ifelse-value
    s-state = "AVAILABLE"            [ shape-station-AVAILABLE     ]
    s-state = "NOT_AVAILABLE"        [ shape-station-NOT_AVAILABLE ]
  )
end ;; update-station

;;------------------------------------------------------------------------------------------------------------------
to error-code [n]
  write "Transition ERROR from " ;; "write" is not followed by a carriage return
  let message (ifelse-value
    n = 1   [ "DRIVING_ON_STREET                     to SEARCHING_STATION" ]
    n = 2   [ "SEARCHING_STATION                     to REACHING_STATION"  ]
    n = 3   [ "SEARCHING_STATION or REACHING_STATION to OUT_OF_SERVICE"    ]
    n = 4   [ "REACHING_STATION                      to CHARGING"          ]
    n = 5   [ "CHARGING                              to DRIVING_ON_STREET" ]
  )
  show message  ;; "show" is followed by a carriage return
  beep
  stop
end ;; error-code
@#$#@#$#@
GRAPHICS-WINDOW
399
15
1076
693
-1
-1
6.76
1
10
1
1
1
0
1
1
1
0
98
0
98
1
1
1
ticks
30.0

BUTTON
260
43
315
76
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

SLIDER
112
335
238
368
car/station-ratio
car/station-ratio
10
20
16.0
2
1
NIL
HORIZONTAL

BUTTON
260
129
315
162
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
260
96
315
129
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
168
246
323
279
charging-time-in-min
charging-time-in-min
0
120
60.0
30
1
NIL
HORIZONTAL

SLIDER
20
335
112
368
#e-cars
#e-cars
0
1000
1000.0
10
1
NIL
HORIZONTAL

TEXTBOX
16
10
251
164
--------------------------------------------\n-------------  ELECTRIC CARS  ---------------\n--------------------------------------------\nMOVING_ON_STREET                                   BLUE\nSEARCHING_FOR_STATION                        GREEN\nREACHING_STATION                                    PINK\nCHARGING                                                   RED\nOUT_OF_SERVICE                                      BLACK \n--------------------------------------------\n-------  PUBLIC CHARGING STATIONS  --------\n--------------------------------------------\nAVAILABLE                                                GREEN\nNO_AVAILABLE                                              RED\n-------------------------------------------\n\n
9
0.0
0

MONITOR
169
291
314
336
NIL
charging-time-in-ticks
0
1
11

MONITOR
18
290
169
335
NIL
car-range-in-ticks
0
1
11

SLIDER
167
170
323
203
car-speed-in-km-h
car-speed-in-km-h
1
50
25.0
1
1
NIL
HORIZONTAL

MONITOR
238
336
314
381
NIL
#c-stations
2
1
11

SLIDER
20
447
313
480
global-car-range-ratio-threshold
global-car-range-ratio-threshold
0.1
.9
0.7
.1
1
NIL
HORIZONTAL

MONITOR
17
246
169
291
car-range-in-min
car-range-in-min
2
1
11

SLIDER
15
170
169
203
car-range-in-km
car-range-in-km
0
600
300.0
10
1
NIL
HORIZONTAL

MONITOR
16
202
169
247
car-range-in-hours
car-range-in-min / 60
2
1
11

MONITOR
168
202
316
247
charging-time-in-hours
charging-time-in-min / 60
2
1
11

MONITOR
176
568
312
613
P_OUT+
count e-cars with [car-range-ratio-threshold = .7 and c-state = \"OUT_OF_SERVICE\"] / count e-cars with [car-range-ratio-threshold = .7]
3
1
11

MONITOR
21
380
114
425
SD ratio
(#c-stations / charging-time-in-ticks) / (#e-cars / car-range-in-ticks)
3
1
11

TEXTBOX
34
484
336
518
Ratio of the car-range beyond which each e-car DRIVING on-street begin to search for a c-station
12
0.0
1

MONITOR
115
380
222
425
SD ratio effectif
(#c-stations / charging-time-in-ticks) / (count e-cars with [c-state != \"OUT_OF_SERVICE\"] / car-range-in-ticks)
3
1
11

SWITCH
20
520
311
553
mobile-app-to-find-EV-charging-stations?
mobile-app-to-find-EV-charging-stations?
0
1
-1000

BUTTON
261
10
316
44
NIL
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
129
367
224
385
#cars per station
11
0.0
1

MONITOR
20
568
135
613
P_OUT-
count e-cars with [car-range-ratio-threshold = .3  and c-state = \"OUT_OF_SERVICE\"] / count e-cars with [car-range-ratio-threshold = .3]
3
1
11

CHOOSER
221
380
313
425
EXPERIENCE
EXPERIENCE
"exp1" "exp2" "exp3" "exp4" "exp5"
0

TEXTBOX
21
431
141
449
EXPERIENCES 1
12
15.0
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

clock
true
0
Circle -7500403 true true 30 30 240
Polygon -16777216 true false 150 31 128 75 143 75 143 150 158 150 158 75 173 75
Circle -16777216 true false 135 135 30

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

lightning
false
0
Polygon -7500403 true true 120 135 90 195 135 195 105 300 225 165 180 165 210 105 165 105 195 0 75 135

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
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300000"/>
    <metric>count e-cars with [c-state = "OUT_OF_SERVICE"] / count e-cars</metric>
    <enumeratedValueSet variable="car/station-ratio">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="charging-time-in-min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobile-app-to-find-EV-charging-stations?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="global-car-range-ratio-threshold">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-range-in-km">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#e-cars">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="car-speed-in-km-h">
      <value value="25"/>
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
