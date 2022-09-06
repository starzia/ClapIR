set terminal png enhanced size 640,832 font "/usr/share/fonts/liberation/LiberationSans-Regular.ttf"
set output "grid2.png"
set lmargin 8.5
set rmargin 2.2
set bmargin 4.7
set multiplot layout 2,1
set border linewidth 2.0
set grid
set xrange [12.5:20000];
set yrange [0:80];
# labels are localized in the app
set ylabel " "
set xtics (16, 31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000) rotate
set log x
set key box

set style line 1 lt 2 lc rgb "black" lw 4
set style line 2 lt 2 lc rgb "red" lw 2
set style line 3 lt 2 lc rgb "yellow" lw 2
# label strings are localized in the app
plot '-' w l title "       " ls 1,'-' w l title "          " ls 2,'-' w l title " " ls 3
10 -1
EOF
10 -1
EOF
10 -1
EOF

unset key
# label strings are localized in the app
set xlabel " "
set ylabel " "
set bmargin 6

# label strings are localized in the app
plot '-' w l title " " ls 1,'-' w l title " " ls 2,'-' w l title "      " ls 3
10 -1
EOF
10 -1
EOF
10 -1
EOF
