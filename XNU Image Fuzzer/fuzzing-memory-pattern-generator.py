#
#  @file fuzzing-memory-pattern-generator.pf
#  @brief Code Analysis for XNU Image Fuzzer
#  @author @h02332 | David Hoyt | @xsscx
#  @date 24 MAY 2024
#  @version 1.2.5
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

def generate_pattern(length):
    pattern = ''
    alpha_upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    alpha_lower = "abcdefghijklmnopqrstuvwxyz"
    digits = "0123456789"

    while len(pattern) < length:
        for upper in alpha_upper:
            for digit in digits:
                for lower in alpha_lower:
                    if len(pattern) < length:
                        pattern += upper + 'a' + digit + lower
                    else:
                        break

    return pattern[:length]

# Example: Create a pattern of 200 characters
pattern = generate_pattern(200)
print(pattern)
