"""The Frost Glacier's new layout and colours (Look 3, picked by the owner 2026-11-22): the reference's flower.
Shared by the look, surface and preview renders; FrostFx.luau gets the same table once the owner says yes."""
import math

GAME_BLUES = [(84, 156, 255), (128, 204, 255), (184, 232, 255), (240, 251, 255)]
PALE_GLASS = [(125, 162, 198), (154, 196, 225), (182, 224, 244), (213, 239, 251)]   # reference C, 5th to 75th percentile

FLOWER_CENTRE = 8


def around(azimuth, radius):
    """A spot `radius` studs from the flower's centre; azimuth 0 = straight ahead, 90 = the thrower's right."""
    a = math.radians(azimuth)
    return (round(math.sin(a) * radius, 2), round(FLOWER_CENTRE + math.cos(a) * radius, 2))


# azimuth, distance from the centre, length, lean, wave, piece, tone. Tall broad blades inside, long low needles
# outside. The footprint is today's: no further ahead than 18.3 studs (the Glacier hits to 15), 16.4 to a side,
# nothing behind the thrower; so the blades that point ahead or back are shorter and steeper than the side ones.
ROWS = (
    (0, 0.0, 10.0, 0, 0, "Ice_Clump", 3),
    (-15, 0.8, 14.0, 8, 0, "Ice_SpikeTall", 0), (40, 0.8, 12.0, 12, 0, "Ice_SpikeTall", 0),
    (-30, 1.5, 19.0, 20, 1, "Ice_SpikeThick", 4), (30, 1.5, 18.0, 22, 1, "Ice_SpikeThick", 2),
    (-80, 1.5, 16.5, 34, 1, "Ice_SpikeThick", 2), (85, 1.5, 16.0, 36, 1, "Ice_SpikeThick", 3),
    (0, 1.5, 16.0, 10, 1, "Ice_SpikeThick", 1), (180, 1.5, 8.0, 20, 1, "Ice_SpikeTall", 3),
    (-140, 1.5, 11.0, 30, 1, "Ice_SpikeTall", 4), (140, 1.5, 11.0, 32, 1, "Ice_SpikeTall", 1),
    (-55, 2.5, 15.0, 40, 2, "Ice_SpikeThick", 3), (55, 2.5, 15.0, 40, 2, "Ice_SpikeThick", 4),
    (-110, 2.5, 13.0, 42, 2, "Ice_SpikeThick", 1), (110, 2.5, 13.0, 42, 2, "Ice_SpikeThick", 2),
    (-75, 3.0, 14.0, 66, 2, "Ice_SpikeTall", 3), (72, 3.0, 13.5, 64, 2, "Ice_SpikeTall", 4),
    (-25, 3.0, 10.0, 56, 2, "Ice_SpikeTall", 2), (22, 3.0, 9.5, 56, 2, "Ice_SpikeTall", 3),
    (-100, 3.0, 12.0, 70, 2, "Ice_SpikeTall", 1), (98, 3.0, 12.0, 70, 2, "Ice_SpikeTall", 1),
    (-135, 2.0, 9.0, 40, 2, "Ice_SpikeTall", 4), (132, 2.0, 9.0, 40, 2, "Ice_SpikeTall", 2),
)
# The three blades nearest the thrower (rows 9-11, behind the middle) are the slim piece: the thick piece's side
# blades splayed out beside the fighter and one read as a loose shard on the ground (seen in the preview).
# Each crystal's turn about its own axis, chosen by fit_yaws.py (the most ice shown to the game camera, inside
# the limits above). Empty until fitted: the scene then falls back to (row x 137) mod 360.
YAWS = (30, 345, 165, 180, 165, 195, 150, 165, 165, 0, 150, 315, 165, 15, 150, 30, 75, 345, 165, 240, 45, 15, 135)

FLOWER = []
for index, (azimuth, radius, length, lean, wave, piece, tone) in enumerate(ROWS):
    r, a = around(azimuth, radius)
    row = (r, a, length, lean, wave, piece, tone)
    FLOWER.append(row + (YAWS[index],) if YAWS else row)
