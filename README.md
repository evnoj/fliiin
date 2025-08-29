an iii (grid) implementation of flin:
- https://monome.org/docs/grid/app/terms/#flin
- https://github.com/monome-community/flin

Each column has a segment that is falling in a virtual space that is twice as high as the grid. The grid is a window into the top half of this space. When a segment falls off the bottom of the grid, they continue falling through this space. When they hit the bottom, they wrap around back to the top. The top row is the playhead row. While a segment crosses this row (i.e. the LED is lit), that column's note is active.
> midi note on sent when the LED lights, and midi note off sent when it goes dark

To create a falling segment, press keys in a column. The first key press determines the rate (clock division) that the segment falls, where first row is /1, 2nd row /2, third row /3, etc., maximum clock division is /15. 2nd key (if pressed) determines the duration (i.e. note length) of the segment, as the length from the top row to that press. A segment starts falling after the keys are released, and starts with its front at the top of the space (i.e. it begins playing its note at the next clock tick after the keys are released).
- To stop a column, press the key on the bottom row of that column.
- Pressing keys in a running column will recreate its segment (in accordance with the presses).
- To cancel an in-progress segment creation (you've pressed one or two keys in a column, but changed your mind and don't want to execute the segment creation), press the bottom key in that column before releasing the other keys.
  - Except for the bottom row to cancel the segment creation, any further key presses after the first two when creating a segment are ignored.
