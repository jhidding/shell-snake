# ~\~ language=Bash filename=snake.sh
# ~\~ begin <<README.md|snake.sh>>[init]
function main {
  # ~\~ begin <<README.md|main>>[init]
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
  # ~\~ end
  # ~\~ begin <<README.md|main>>[1]
  # place first food
  typeset -i fx=hx fy=hy
  while (( fx == hx && fy == hy )); do
    fx=$(( RANDOM % (width-2)+1 )) fy=$(( RANDOM % (height-2)+1 ))
  done
  tput cup "$fy" "$fx" && printf '*'
  # ~\~ end
  # ~\~ begin <<README.md|main>>[2]
  # handle variations between shells
  keypress=(-N 1) origin=0
  if [[ -n $ZSH_VERSION ]]; then
    keypress=(-k)
    origin=1
  fi
  # ~\~ end
  # ~\~ begin <<README.md|main>>[3]
  stty -echo
  tput civis
  # ~\~ end
  # ~\~ begin <<README.md|main>>[4]
  typeset key
  read "${keypress[@]}" -s key
  # ~\~ end
  # ~\~ begin <<README.md|main>>[5]
  typeset -i start_time=$(date +%s)
  # ~\~ end
  # ~\~ begin <<README.md|main>>[6]
  tput cup "$(( height/2+2 ))" 0 && tput el
  while (( ! game_over )); do
    # ~\~ begin <<README.md|read-key-stroke>>[init]
    timeout=(-t $(printf '0.%04d' $(( 2000 / (${#sx[@]}+1) )) ) )
    if [[ -z $key ]]; then
      read "${timeout[@]}" "${keypress[@]}" -s key
    fi
    # ~\~ end
    # ~\~ begin <<README.md|handle-input>>[init]
    case "$key" in
      a) if (( dx !=  1 )); then dx=-1; dy=0; fi;;
      o) if (( dy != -1 )); then dy=1;  dx=0; fi;;
      ,) if (( dy !=  1 )); then dy=-1; dx=0; fi;;
      e) if (( dx != -1 )); then dx=1;  dy=0; fi;;
      q) game_over=1; tput cup 0 0 && print "Final food was at ($fx,$fy)";;
    esac
    key=
    # ~\~ end
    # ~\~ begin <<README.md|update-state>>[init]
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
    # ~\~ end
    # ~\~ begin <<README.md|update-state>>[1]
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
    # ~\~ end
  done
  # ~\~ end
  # ~\~ begin <<README.md|main>>[7]
  typeset -i end_time=$(date +%s)
  tput cup $(( height / 2 -1 )) 0 && center $width 'GAME OVER'
  tput cup $(( height / 2 ))  0 &&
      center $width 'Time: %d seconds' $(( end_time - start_time ))
  tput cup $(( height / 2 + 1 )) 0 &&
      center $width 'Final length: %d' ${#sx[@]}
  echo
  stty echo
  tput cnorm
  # ~\~ end
}

# ~\~ begin <<README.md|function-center>>[init]
function center {
  typeset -i width=$1 i
  shift
  typeset message=$(printf "$@")
  tput cuf $(( (width-${#message}) / 2 ))
  printf '%s' "$message"
}
# ~\~ end
main "$@"
# ~\~ end
