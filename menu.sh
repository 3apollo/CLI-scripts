#!/bin/bash

#functions

options (){
    echo "
1) Test Ram
2) Test HDD/SSD
0) Exit
    "
}

#end of functions

echo "Hi there $USER, welcome to my menu script. Please select an option from below."

while true; do
options
read -p "Please select an option: " option

case "$option" in

