set terminal png enhanced size 640,832 font "/usr/share/fonts/liberation/LiberationSans-Regular.ttf"
set output "grid2.png"
set multiplot layout 2,1
set grid
set xrange [22:19027];
set yrange [0:80];
set ylabel "Direct sound power (dB)"
set xtics (31,62,125,250,500,1000,2000,4000,8000,16000) rotate by 90
set log x
set key box

set style line 1 lt 2 lc rgb "black" lw 4
set style line 2 lt 2 lc rgb "red" lw 2
set style line 3 lt 2 lc rgb "yellow" lw 2
plot '-' w l title "Average" ls 1,'-' w l title "Most recent measurement" ls 2,'-' w l title "Prior measurements" ls 3
10 -1
EOF
10 -1
EOF
10 -1
EOF

unset key
set xlabel "Frequency (Hz)"
set ylabel "Frequency response (dB)"

plot '-' w l title "Average" ls 1,'-' w l title "Most recent measurement" ls 2,'-' w l title "Prior measurements" ls 3
10 -1
EOF
10 -1
EOF
10 -1
EOF
