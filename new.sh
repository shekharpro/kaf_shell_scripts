something() {
    while getopts a:b: flag; do
        case "${flag}" in
        a) num1=${OPTARG} ;;
        b) num2=${OPTARG} ;;
        esac
    done

    divide() {
    
      echo $(bc -e "scale=3;$1/$2")
    }

    echo "((num1/num2)) = " $(($num1/$num2))
    echo "devide num1 num 2 = " $(divide $num1 $num2)

}

something -a $1 -b $2