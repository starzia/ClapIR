set terminal png enhanced size 640,832 font "/usr/share/fonts/liberation/LiberationSans-Regular.ttf"
set output "grid2.png"
set multiplot layout 2,1
set grid
set xrange [22:19027];
set yrange [0:20];
set ylabel "Direct sound power (dB)"
set xtics (31,62,125,250,500,1000,2000,4000,8000,16000) rotate by 90
set log x
unset key

plot '-'
10 -1
EOF

set xlabel "Frequency (Hz)"
set ylabel "Frequency response (dB)"

plot '-'
10 -1
EOF
