// Experiment with asm and macros

basics :: () {
    banana := 17;
    apple := 10;
    #asm {
        // mov apple:, 10;
        // banana: gpr;
        // mov.64  banana, 17;
    }

    count := 10;

    #asm {
        add count, 17;
    }

    {
        to_print := count;
        print("count is %\n", to_print);
    }

    #asm {
        sub banana, apple;
        add count, banana;
    }

    // to_print := count;
    print_asm("count with apple and banana is %\n", count);//, banana);
    print_asm("count with apple and banana is %, and banana %\n", count, banana);
    print_asm("count with apple and banana is %, banana %, and apple %\n", count, banana, apple);
    print_asm("count with apple and banana is %, banana %, and apple %, banana %, banana %, banana %, banana %, banana %, banana %, banana %\n",
              count, banana, apple, banana, banana, banana, banana, banana, banana, banana);
}
// Version of print, that create a to_print intermediate variable to print an asm register, or something,
// see jai-beta-2-028/jai/how_to/900_inline_assembly.jai:59
// print :: (format_string: string, args: .. Any) -> bytes_printed: s64;
print_asm :: (format_string: string, arg0: Code) -> bytes_printed: s64 #expand{
    print(format_string,
        // WHY? Because we wanted to test things for the varargs version of print_asm
        // We use this trick to get a scope that returns an expression result, but there might be a less hacky way ^^"""
        ifx true {
            to_print_arg0 := #insert arg0;
            to_print_arg0;
        }
    );
}
// ARRAY :: #code [[arg0], [arg0, arg1]]


print_asm :: (format_string: string, arg0: Code, arg1: Code) -> bytes_printed: s64 #expand{
    print(format_string,
        // WHY? Because we wanted to test things for the varargs version of print_asm
        // We use this trick to get a scope that returns an expression result, but there might be a less hacky way ^^"""
        ifx true {
            to_print_arg0 := #insert arg0;
            to_print_arg0;
        },
        ifx true {
            to_print_arg1 := #insert arg1;
            to_print_arg1;
        }
    );
}

print_asm :: (format_string: string, args: .. $T) -> bytes_printed: s64 {
    to_print : [10]Any;
    for args{
       to_print[it_index]  = it;
    }
    return print(format_string, ..to_print);
}

// // TODO try to do a generic version of it, for fun
// print_asm :: (format_string: string, $$args: .. Code) -> bytes_printed: s64 #expand{
//     to_print_vars : [2] Any;
//     for args {
//         #run {
//             to_print_vars[it_index] = #insert it;
//         }
//     }
//     print(format_string, .. to_print_vars);
// }

main :: () {
    basics();
    b := ifx true {
        a := 2;
        a + 2;
    }
}

#import "Basic";
