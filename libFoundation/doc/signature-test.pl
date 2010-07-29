#! /usr/local/bin/perl

@types = (
    'char', 
    'short',
    'int',
    'long',
    'float',
    'double',
    'void*',
    'Struct1',
    'Struct2',
    'Struct3',
    'Struct4',
    'Struct5',
    'Struct6',
    'Struct7',
    'Struct8'
);

%type_encoding = (
    'char' => 'c',
    'short' => 's',
    'int' => 'i',
    'long' => 'l',
    'float' => 'f',
    'double' => 'd',
    'void*' => '^v',
    'Struct1' => '{?=c}',
    'Struct2' => '{?=s}',
    'Struct3' => '{?=sc}',
    'Struct4' => '{?=i}',
    'Struct5' => '{?=ic}',
    'Struct6' => '{?=is}',
    'Struct7' => '{?=isc}',
    'Struct8' => '{?=ii}'
);

%type_method_name = (
    'char' => 'c',
    'short' => 's',
    'int' => 'i',
    'long' => 'l',
    'float' => 'f',
    'double' => 'd',
    'void*' => 'p',
    'Struct1' => 's1',
    'Struct2' => 's2',
    'Struct3' => 's3',
    'Struct4' => 's4',
    'Struct5' => 's5',
    'Struct6' => 's6',
    'Struct7' => 's7',
    'Struct8' => 's8'
);

# The maximum number of arguments a method should have
$no_of_args = 2;

sub generate_methods_file {
    local ($file,
	    $file_prologue, $file_epilogue,
	    $method_prefix, $method_code,
	    $initial_acc_args
    ) = @_;

    $FILE = "> $file";
    #$FILE = ">-";
    open(FILE) or die "cannot open file: $!\n";
    print FILE $file_prologue;

    # The number of methods generated
    $methods_generated = 0;

    gen_method($no_of_args, $method_prefix, $method_code, $initial_acc_args);
    print FILE $file_epilogue;

    print "$methods_generated methods generated in file $file.\n";
}

sub gen_method {
    local ($mth_no_of_args,
	    $method_prefix, $method_code,
	    $initial_acc_args
    ) = @_;

    gen_method1(0, $mth_no_of_args, "", $initial_acc_args,
			    $method_prefix, $method_code);
}

sub gen_method1 {
    local (
	    $curr_type_no, $curr_arg_no,
	    $acc_mth_name, $acc_args,
	    $method_prefix, $method_code
    ) = @_;

    if ($curr_arg_no == 0) {
	print FILE "$method_prefix";
	if ($acc_mth_name ne "") {
		print FILE "${acc_mth_name}${acc_args}";
	}
	print FILE $method_code;
	$methods_generated++;
	print "$methods_generated\r";
	return;
    }

    # Determine the preceding types. We not generate the methods that have more
    # than 2 identical types in consecutive positions.
    local $prev_type = "";
    if ($acc_mth_name =~ /.*_(.*)$/) {
	    $prev_type = $acc_mth_name;
	    $prev_type =~ s/.*_(.*)$/$1/;
    }

    for (local $curr_type_no = 0; $curr_type_no <= $#types; $curr_type_no++) {
	local $label = $type_method_name{$types[$curr_type_no]};

	if(!($label eq $prev_type)) {
	    gen_method1($curr_type_no, $curr_arg_no - 1,
		    "${acc_mth_name}_$label",
		    &$show_acc_args($acc_args, $curr_type_no, $curr_arg_no),
		    $method_prefix, $method_code);
	}
    }
}

$source_file = __FILE__;

$show_acc_args = sub {
    local ($acc_args, $curr_type_no, $curr_arg_no) = @_;
    local $number = $no_of_args - $curr_arg_no;
    local $label = $type_method_name{$types[$curr_type_no]};

    return "$acc_args:($types[$curr_type_no])${label}${number} ";
};

generate_methods_file("SignatureTest.m",
"/* Do not modify! Generated automatically from $source_file. */

#include <objc/Object.h>

typedef struct {
char c;
} Struct1;

typedef struct {
short s;
} Struct2;

typedef struct {
short s;
char c;
} Struct3;

typedef struct {
int i;
} Struct4;

typedef struct {
int i;
char c;
} Struct5;

typedef struct {
int i;
short s;
} Struct6;

typedef struct {
int i;
short s;
char c;
} Struct7;

typedef struct {
int i;
int j;
} Struct8;

\@interface SignatureTest : Object
\@end

\@implementation SignatureTest

", "
\@end /* SignatureTest */
", "- (void)method",
"{}
",
"");


$show_acc_args = sub {
    local ($acc_args, $curr_type_no, $curr_arg_no) = @_;

    return ":${acc_args}";
};

generate_methods_file("test.m",
"/* Do not modify! Generated automatically from $source_file. */
#include <stdio.h>
#include <objc/objc.h>
#include <objc/objc-api.h>
#include \"SignatureTest.m\"

void main()
{
    id signtest = [[SignatureTest alloc] init];
    struct objc_method* mth;

", "
}
",
"    mth = class_get_instance_method([signtest class], \@selector(method",
"));
    printf(\"'%s' is '%s'\\n\", sel_get_name(mth->method_name), mth->method_types);
",
"");
