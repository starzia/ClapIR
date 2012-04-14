set terminal png enhanced size 640,832 font "/usr/share/fonts/liberation/LiberationSans-Regular.ttf"
set output "grid.png"
set grid
set xrange [22:19027];
set yrange [0:3];
set xlabel "Frequency (Hz)"
set ylabel "RT60 Reverb Time (seconds)"
set xtics (31,62,125,250,500,1000,2000,4000,8000,16000) rotate by 90
set ytics (0,"" 0.2,"" 0.4, "" 0.6, "" 0.8, 1, "" 1.2, "" 1.4, "" 1.6,"" 1.8,2,"" 2.2, "" 2.4, "" 2.6, "" 2.8, 3)
set ytics (0,0.2,0.4, 0.6, 0.8, 1, 1.2, 1.4, 1.6,1.8,2,2.2, 2.4, 2.6, 2.8, 3)
set lmargin 9
set rmargin 2
set bmargin 4
set log x
unset key
plot '-'
10 -1
EOF
