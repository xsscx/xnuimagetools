#!/usr/bin/env python3

#
#  @file code_analysis.py
#  @brief Code Analysis for XNU Image Tools
#  @author @h02332 | David Hoyt | @xsscx
#  @date 27 MAY 2024
#  @version 1.1.7
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#  @section CHANGES
#  - 24/05/2024 - Add to Public Repo
#
#  @section TODO
#  - Better Images
#

import re
import matplotlib.pyplot as plt
import pandas as pd

def analyze_code(file_content):
    """
    Analyze the code to gather statistics about the code structure and documentation.
    
    Args:
    file_content (str): The content of the code file.
    
    Returns:
    dict: A dictionary containing various statistics about the code.
    """
    lines = file_content.split('\n')
    total_lines = len(lines)
    code_lines = 0
    comment_lines = 0
    inline_comments = 0
    block_comments = 0
    blank_lines = 0
    todo_comments = 0
    fixme_comments = 0

    # Improved regex patterns
    function_pattern = re.compile(r'\b(?:[a-zA-Z_]\w*\s+)+([a-zA-Z_]\w*)\s*\([^)]*\)\s*{')
    documented_function_pattern = re.compile(r'/\*\*.*?\*/\s*\n\s*(?:[a-zA-Z_]\w*\s+)+([a-zA-Z_]\w*)\s*\([^)]*\)\s*{', re.DOTALL)
    specific_function_pattern = re.compile(r'#pragma mark - dump_comm_page\s')
    pragma_pattern = re.compile(r'#pragma mark -\s*(.*)')

    functions = function_pattern.findall(file_content)
    documented_functions = documented_function_pattern.findall(file_content)
    pragma_marks = pragma_pattern.findall(file_content)
    
    # Check if dump_comm_page is documented
    specific_function_match = specific_function_pattern.search(file_content)
    if specific_function_match:
    #    print("Match for documented dump_comm_page found:")
    #    print(specific_function_match.group())
        documented_functions.append('dump_comm_page')
    else:
        print("No match for documented dump_comm_page")

    class_definitions = re.findall(r'\bclass\s+\w+\s*{', file_content)
    variable_declarations = re.findall(r'\b\w+\s+\w+\s*(=|;)', file_content)
    loops = re.findall(r'\b(for|while)\s*\([^)]*\)\s*{', file_content)
    conditionals = re.findall(r'\bif\s*\([^)]*\)\s*{', file_content)

    in_block_comment = False
    current_function_lines = 0
    function_lengths = []

    documented_function_names = set(documented_functions)

    for line in lines:
        stripped_line = line.strip()
        if not stripped_line:
            blank_lines += 1
        elif stripped_line.startswith('/*'):
            block_comments += 1
            comment_lines += 1
            in_block_comment = True
        elif stripped_line.endswith('*/'):
            block_comments += 1
            comment_lines += 1
            in_block_comment = False
        elif in_block_comment:
            comment_lines += 1
        elif stripped_line.startswith('//'):
            comment_lines += 1
            inline_comments += 1
            if 'TODO' in stripped_line:
                todo_comments += 1
            if 'FIXME' in stripped_line:
                fixme_comments += 1
        elif stripped_line:
            code_lines += 1

        if '{' in stripped_line:
            current_function_lines = 1
        elif '}' in stripped_line and current_function_lines > 0:
            function_lengths.append(current_function_lines)
            current_function_lines = 0
        elif current_function_lines > 0:
            current_function_lines += 1

    avg_function_length = sum(function_lengths) / len(function_lengths) if function_lengths else 0
    longest_function = max(function_lengths) if function_lengths else 0

    all_function_names = set(functions) - set(['if', 'for', 'switch'])
    undocumented_function_names = all_function_names - documented_function_names

    return {
        'total_lines': total_lines,
        'code_lines': code_lines,
        'comment_lines': comment_lines,
        'functions': len(functions),
        'documented_functions': len(documented_function_names),
        'avg_function_length': avg_function_length,
        'longest_function': longest_function,
        'inline_comments': inline_comments,
        'block_comments': block_comments,
        'comment_density': (comment_lines / total_lines) * 100 if total_lines else 0,
        'blank_lines': blank_lines,
        'todo_comments': todo_comments,
        'fixme_comments': fixme_comments,
        'class_definitions': len(class_definitions),
        'variable_declarations': len(variable_declarations),
        'loops': len(loops),
        'conditionals': len(conditionals),
        'all_function_names': all_function_names,
        'documented_function_names': documented_function_names,
        'undocumented_function_names': undocumented_function_names,
        'function_lengths': function_lengths,
        'pragma_marks': pragma_marks
    }

# Plotting functions
def plot_analysis(analysis, title, filename):
    """
    Plot the code analysis results and save the plot to a file.

    Args:
    analysis (dict): The analysis results from the code.
    title (str): The title for the plot.
    filename (str): The filename to save the plot.
    """
    labels = ['Total Lines', 'Code Lines', 'Comment Lines', 'Functions', 'Documented Functions', 'Inline Comments', 'Block Comments', 'Blank Lines', 'TODO Comments', 'FIXME Comments', 'Class Definitions', 'Variable Declarations', 'Loops', 'Conditionals']
    values = [analysis['total_lines'], analysis['code_lines'], analysis['comment_lines'], analysis['functions'], analysis['documented_functions'], analysis['inline_comments'], analysis['block_comments'], analysis['blank_lines'], analysis['todo_comments'], analysis['fixme_comments'], analysis['class_definitions'], analysis['variable_declarations'], analysis['loops'], analysis['conditionals']]
    
    fig, ax = plt.subplots()
    ax.bar(labels, values, color='blue')
    ax.set_title(title)
    ax.set_ylabel('Count')
    plt.xticks(rotation=45, ha='right')
    plt.yscale('log')  # Use logarithmic scale to handle small and large values
    plt.tight_layout()
    plt.savefig(filename)
    plt.close(fig)
    
def plot_function_lengths(analysis, title, filename):
    """
    Plot the distribution of function lengths and save the plot to a file.

    Args:
    analysis (dict): The analysis results from the code.
    title (str): The title for the plot.
    filename (str): The filename to save the plot.
    """
    fig, ax = plt.subplots()
    ax.hist(analysis['function_lengths'], bins=10, color='green', edgecolor='black')
    ax.set_title(f'Function Length Distribution in {title}')
    ax.set_xlabel('Function Length (Lines)')
    ax.set_ylabel('Frequency')
    plt.tight_layout()
    plt.savefig(filename)
    plt.close(fig)

# Tabular summary of findings
def create_summary_table(analysis):
    """
    Create and print a summary table of the analysis results.

    Args:
    analysis (dict): The analysis results from the code.
    """
    data = {
        'Metric': ['Total Lines', 'Code Lines', 'Comment Lines', 'Functions', 'Documented Functions', 'Inline Comments', 'Block Comments', 'Blank Lines', 'TODO Comments', 'FIXME Comments', 'Class Definitions', 'Variable Declarations', 'Loops', 'Conditionals'],
        'Count': [analysis['total_lines'], analysis['code_lines'], analysis['comment_lines'], analysis['functions'], analysis['documented_functions'], analysis['inline_comments'], analysis['block_comments'], analysis['blank_lines'], analysis['todo_comments'], analysis['fixme_comments'], analysis['class_definitions'], analysis['variable_declarations'], analysis['loops'], analysis['conditionals']]
    }
    df = pd.DataFrame(data)
    print(df.to_string(index=False))

# Load the file content
file_path = "/mnt/xnuimagefuzzer/xnuimagefuzzer.m"
with open(file_path, 'r') as file:
    file_content = file.read()

# Analyze the code
xif_analysis = analyze_code(file_content)

# Plot the analysis results
plot_analysis(xif_analysis, 'Code Analysis of xnuimagefuzzer.m', '/mnt/reports/xnuimagefuzzer/code_analysis.png')
plot_function_lengths(xif_analysis, 'Function Length Distribution of xnuimagefuzzer.m', '/mnt/reports/xnuimagefuzzer/function_length_distribution.png')

# Print the results
print("Analysis of xnuimagefuzzer.m:")
print(xif_analysis)

# Print documented and undocumented functions
def print_function_analysis(analysis):
    """
    Print the list of functions with their documentation status.

    Args:
    analysis (dict): The analysis results from the code.
    """
    print("\nFunctions Analysis:")
    for func in sorted(analysis['all_function_names']):
        status = '(D)' if func in analysis['documented_function_names'] else '(U)'
        print(f"  - {func} {status}")

# Print pragma marks
def print_pragma_marks(analysis):
    """
    Print the list of pragma marks found in the code.

    Args:
    analysis (dict): The analysis results from the code.
    """
    print("\nPragma Marks:")
    for mark in sorted(analysis['pragma_marks']):
        print(f"  - {mark}")

print_function_analysis(xif_analysis)
print_pragma_marks(xif_analysis)

# Create and display the summary table
create_summary_table(xif_analysis)

