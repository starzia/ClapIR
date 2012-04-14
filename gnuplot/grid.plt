set terminal png size 640,640
set output "grid.png"
set grid
set xrange [22:19027];
set yrange [0:5];
set xlabel "Frequency (Hz)"
set ylabel "Reverb Time (RT60)"
set xtics (31,62,125,250,500,1000,2000,4000,8000,16000)
set log x
unset key
plot '-'
10 -1
EOF
