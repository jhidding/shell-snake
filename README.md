---
title: Snake in UNIX shell
subtitle: disentangling a legacy code
author: Johan Hidding
---

# Intro
The following is a Bash script found on Rosetta's Code. This script implements a basic version of the game of Snake and seems to have been contributed by Mark J. Reed. Let's see how it works. Here's a screenshot after a particularly unsuccessful game:

```txt


@@@@                                                                  *
                                                                      
                                                                      
                                                                      
                                   GAME OVER                               
                                Time: 27 seconds                           
                                Final length: 4                            
                                                                  



```

## Bash functions
My Bash is a bit rusty, so here is some relevant documentation:

- `typeset` declares a variable of a certain type. The `-i` flag means integer, `-a` is for arrays.
- `clear`, clears the screen.
- `tput` output special operators to terminal, specifically (`man terminfo`):
  - `tput cup` set cursor position
  - `tput civis` set cursor to invisible
  - `tput cnorm` set cursor back to normal
  - `tput el` clear to end of line
- `stty` set how terminal interacts, specifically:
  - `stty -echo` disable input echo
  - `stty echo` enable input echo
- `read [-t <t>] [-N <n>] [-s] <var>` reads `<n>` number of characters from input in `-s` silent mode, on `<t>` seconds, put result in `<var>`.
- `$((RANDOM))` or `$RANDOM` draws a random integer in the range 0 - 32767.
- Anything in double parentheses can do arithmetic and allows for a C-like syntax.

# Code
We start by defining a `main` function and a `center` function.

``` {.bash file=snake.sh}
function main {
  <<main>>
}

<<function-center>>
main "$@"
```

The `center` function seems to be used to print messages that are centered on the console.

``` {.bash #function-center}
function center {
  typeset -i width=$1 i
  shift
  typeset message=$(printf "$@")
  tput cuf $(( (width-${#message}) / 2 ))
  printf '%s' "$message"
}
```

## Setup
We'll see a lot of `tput cup "$y" "$x" && printf '0'` in here. This is just: put the character `0` on location `x, y`.

``` {.bash #main}
typeset -i game_over=0
typeset -i height=$(tput lines) width=$(tput cols)

# start out in the middle moving to the right
typeset -i dx dy hx=$(( width/2 )) hy=$(( height/2 ))
typeset -a sx=($hx) sy=($hy)
typeset -a timeout
clear
tput cup "$sy" "$sx" && printf '@'
tput cup $(( height/2+2 )) 0
center $width "Press h, j, k, l to move left, down, up, right"
```

The `fx` and `fy` coordinates tell us where the food is.

``` {.bash #main}
# place first food
typeset -i fx=hx fy=hy
while (( fx == hx && fy == hy )); do
  fx=$(( RANDOM % (width-2)+1 )) fy=$(( RANDOM % (height-2)+1 ))
done
tput cup "$fy" "$fx" && printf '*'
```

This little bit also makes the script work with Zshell.

``` {.bash #main}
# handle variations between shells
keypress=(-N 1) origin=0
if [[ -n $ZSH_VERSION ]]; then
  keypress=(-k)
  origin=1
fi
```

Set the terminal to non-echo mode and hide the cursor.

``` {.bash #main}
stty -echo
tput civis
```

Wait until a key is pressed.

``` {.bash #main}
typeset key
read "${keypress[@]}" -s key
```

``` {.bash #main}
typeset -i start_time=$(date +%s)
```

## Main loop
We'll look at several stages in the main loop:

- read a key
- handle potential key press
- update game state and display

The loop ends when `game_over` is signaled.

``` {.bash #main}
tput cup "$(( height/2+2 ))" 0 && tput el
while (( ! game_over )); do
  <<read-key-stroke>>
  <<handle-input>>
  <<update-state>>
done
```

We read a potential key stroke with a timeout of say 0.1 seconds, by calling `read -n 1 -t 0.1 -s key`. After that function is done, and a key has been pressed, the variable `$key` will contain the corresponding character.

``` {.bash #read-key-stroke}
timeout=(-t $(printf '0.%04d' $(( 2000 / (${#sx[@]}+1) )) ) )
if [[ -z $key ]]; then
  read "${timeout[@]}" "${keypress[@]}" -s key
fi
```

The game uses `hjkl` to move around, like vim. If you prefer `asdw`, this is where to change that. Since I use Dvorak layout, this becomes `aoe,`.

``` {.bash #handle-input}
case "$key" in
  a) if (( dx !=  1 )); then dx=-1; dy=0; fi;;
  o) if (( dy != -1 )); then dy=1;  dx=0; fi;;
  ,) if (( dy !=  1 )); then dy=-1; dx=0; fi;;
  e) if (( dx != -1 )); then dx=1;  dy=0; fi;;
  q) game_over=1; tput cup 0 0 && print "Final food was at ($fx,$fy)";;
esac
key=
```

``` {.bash #update-state}
(( hx += dx, hy += dy ))
# if we try to go off screen, game over
if (( hx < 0 || hx >= width || hy < 0 || hy >= height )); then
   game_over=1
else
  # if we run into ourself, game over
  for (( i=0; i<${#sx[@]}; ++i )); do
    if (( hx==sx[i+origin] && hy==sy[i+origin] )); then
      game_over=1
      break
    fi
  done
fi
if (( game_over )); then
   break
fi
# add new spot
sx+=($hx) sy+=($hy)
```

The next bit also takes care of updating the screen.

``` {.bash #update-state}
if (( hx == fx  && hy == fy )); then
  # if we just ate some food, place some new food out
  ok=0
  while  (( ! ok )); do
    # make sure we don't put it under ourselves
    ok=1
    fx=$(( RANDOM % (width-2)+1 )) fy=$(( RANDOM % (height-2)+1 ))
    for (( i=0; i<${#sx[@]}; ++i )); do
      if (( fx == sx[i+origin] && fy == sy[i+origin] )); then
        ok=0
        break
      fi
    done
  done
  tput cup "$fy" "$fx" && printf '*'
  # and don't remove our tail because we've just grown by 1
else
  # if we didn't just eat food, remove our tail from its previous spot
  tput cup ${sy[origin]} ${sx[origin]} && printf ' '
  sx=( ${sx[@]:1} )
  sy=( ${sy[@]:1} )
fi
# draw our new head
tput cup "$hy" "$hx" && printf  '@'
```

## Post mortem
When it is game over, some messages are printed and we return the terminal to normal behaviour.

``` {.bash #main}
typeset -i end_time=$(date +%s)
tput cup $(( height / 2 -1 )) 0 && center $width 'GAME OVER'
tput cup $(( height / 2 ))  0 &&
    center $width 'Time: %d seconds' $(( end_time - start_time ))
tput cup $(( height / 2 + 1 )) 0 &&
    center $width 'Final length: %d' ${#sx[@]}
echo
stty echo
tput cnorm
```

