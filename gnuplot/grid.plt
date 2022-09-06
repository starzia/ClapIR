set terminal png enhanced size 640,832 font "/System/Library/Fonts/Geneva.ttf"
set output "grid.png"
set grid
set border linewidth 2.0
set xrange [12.5:20000];
set yrange [0:3];
set xlabel " " # this is localized in the app, so don't print it
set ylabel " " # this is localized in the app, so don't print it
set xtics (16, 31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000) rotate
set ytics (0,"" 0.2,"" 0.4, "" 0.6, "" 0.8, 1, "" 1.2, "" 1.4, "" 1.6,"" 1.8,2,"" 2.2, "" 2.4, "" 2.6, "" 2.8, 3)
set ytics (0,0.2,0.4, 0.6, 0.8, 1, 1.2, 1.4, 1.6,1.8,2,2.2, 2.4, 2.6, 2.8, 3)
set lmargin 8.2
set rmargin 1.6
set bmargin 4.5
set log x
set key box
set style line 1 lt 2 lc rgb "black" lw 4
set style line 2 lt 2 lc rgb "red" lw 2
set style line 3 lt 2 lc rgb "yellow" lw 2
# labels are localized in the app, so don't print them there
plot '-' w l title " " ls 1,'-' w l title " " ls 2,'-' w l title "          " ls 3
10 -1
EOF
10 -1
EOF
10 -1
EOF
