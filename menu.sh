#!/bin/bash

#functions

options (){
    echo "
1) Test Ram
2) Test HDD/SSD
3) Status Battery
0) Exit
    "
}

#end of functions

echo "Hi there $USER, welcome to my menu script. Please select an option from below."

while true; do
options
read -p "Please select an option: " option

case "$option" in
    1)
        echo "Testing RAM..."
        bash diagnostics/ram.sh
        ;;
    2)
        echo "Testing HDD/SSD..."
        bash diagnostics/ssd.sh
        ;;
    3)
        echo "Checking Battery Status..."
        bash diagnostics/batterystats.sh
        ;;
    0)
        echo "Exiting. Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid option, please try again."
        ;;
esac
done
