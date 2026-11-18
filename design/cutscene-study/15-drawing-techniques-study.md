# 15 - Drawing techniques study: perspective, curvilinear distortion and pencil marks

2026-11-18. The user rejected the sketched torso-and-fist frame on three counts.
- **Marks:** "not what i mean by sketchy, i mean that both shapes should not be distinct shapes but look as if they
  were drawn through scratchy pencil marks".
- **Separation:** "the two shapes should be distinct, currently they seem fused together".
- **Motion:** "the fist shouldnt move forward that much, instead the torso should bend inwards".

They also asked for no 3D modelling ("a bad crutch"): use the vanishing point and round lines inward. They sent six
references on perspective and distortion and asked for "an advanced study for drawing techniques". This is that study:

- what each reference does;
- the techniques behind them, with rules exact enough to code;
- how they apply to the impact frame.

Practice plates are in `design/vfx/study/out/plate_*.png` (`design/vfx/study/plates.ps1`).

## 1. The references, one by one

| # | Reference | Perspective | How the marks build it |
|---|---|---|---|
| 1 | "The Subway", marker in a sketchbook | One-point: the tunnel's end is the single vanishing point (VP). Seams along the tunnel radiate from it. The rings get smaller and **closer together** with depth. | Thick black outline on the nearest ring; thin seam lines; colour strokes follow the tile rows; white highlights along the floor's ridge. |
| 2 | Metro station, fineliner | One-point. **The construction lines to the VP are left in**, running through everything. Arches repeat, shrinking toward the VP. | Every arch band drawn with 2-3 parallel curves. Hatching in straight parallel strokes, **one direction per plane** (walls diagonal, column bases vertical). Floor tiles: converging lines plus crossing lines whose spacing compresses with depth. Lines overshoot their corners. |
| 3 | Surreal pencil scene | Curvilinear (fisheye-type): grid lines radiate from a centre VP and the "horizontals" become arcs round it. **The objects bend to follow the curved grid.** | Light construction grid over the whole page. Each object's edges are several light strokes, and its side planes are shaded with hatching. Darks sit on the insides of the curves. |
| 4 | Fisheye room seen from above | Five-point, looking down. The nadir VP is in the middle: the walls' verticals radiate from it and the room's horizontals curl round it as arcs. The image is a circle. | Loose line art with overshoots, three values (light, mid marker, dark accents), marker strokes laid along each plane. |
| 5 | "Step 8": a circle in a square, in perspective | The square becomes a trapezoid aimed at the VP, and the circle becomes an **ellipse touching the midpoints of the four sides**. | Construction: the box, its diagonals (which give the centre), and the ellipse fitted inside. |
| 6 | Van Gogh's corridor, with the horizon and VP marked | One-point. The arches repeat smaller toward the VP on the horizon line, and the floor recedes. | **The brush strokes follow the surfaces:** flat dabs on the floor, strokes curving along the vaults. |

What they have in common:
1. **One point controls the picture.** Everything is aimed at a vanishing point, and that point is where the eye goes.
2. **Repetition shrinking toward it** (rings, arches, tiles) gives the depth. The spacing compresses with distance.
3. **Curves are straight lines bent by the lens or the form.** In 3, 4 and 1, "straight" edges are arcs.
4. **The drawing is built from marks:**
   - construction lines left visible;
   - edges made of several strokes;
   - tone made of hatching laid in the direction of the surface.
   No region is a flat fill with an outline round it.

## 2. Techniques

### 2.1 Linear perspective (one, two, three points)
- **Horizon line** = eye level. Every set of parallel lines meets at its own VP. Lines parallel to the picture stay
  parallel.
- **Point counts:**
  - one-point: one face square-on, depth lines to one VP;
  - two-point: a corner toward the viewer, two VPs on the horizon;
  - three-point: a third VP above or below for the verticals.
- **Spacing of equal steps in depth** (rings, tiles, arches). A step at depth z appears at a size ∝ 1/z, so with
  equal depth steps s from a first ring at depth d, ring k has radius r_k = r_0 · d / (d + k·s). The gaps shrink
  toward the VP.
- **The diagonal method does the same by hand:**
  1. Draw the first rectangle.
  2. Find its middle line (from the diagonals).
  3. Draw a diagonal from a corner through the middle of the far edge; where it lands is the next rectangle's edge.

### 2.2 Circles and ellipses in perspective
- Build the square in perspective first. Its diagonals give the centre, and lines through the centre (to the VP and
  parallel) give the four midpoints. The ellipse touches the square at those four midpoints.
- **The circle's centre is not the ellipse's centre:** the near half is bigger.
- **Rule of thumb:** the ellipse's minor axis points along the axis of the cylinder (toward the VP of the direction
  perpendicular to the circle's plane). This is approximate (Proko's forum calls it a rule of thumb); fitting to the
  square is what is exact.
- **Exact by code** (`plates.ps1`): map the unit square onto the drawn trapezoid with a homography (the 2D projective
  map defined by 4 corner pairs), then map the circle's points through it. This is plane geometry, not 3D modelling.

### 2.3 Curvilinear perspective (fisheye, 4- and 5-point)
- **Layout:** a centre VP plus four on a circle round it (N, E, S, W). The image of a full hemisphere fits in that
  circle.
- **Straight lines become arcs.** Each straight line becomes a circle arc through its two vanishing points (exact
  for the stereographic projection; close enough by eye for other fisheyes). So:
  - lines through the centre stay straight (radials);
  - lines parallel to the picture become arcs through the pair of VPs on the boundary circle, bending more the
    further they are from the centre.
- **Construction:** draw straight guides from the VPs to find the intersections first, then bend them into arcs. This
  was codified by Barre and Flocon (1968).
- **Two ways to use it on objects:**
  - the whole picture bends (a lens, as in references 3 and 4);
  - one spot of the picture bends (a local lens): this is the impact dent.

### 2.4 Cross-contour lines: drawing a surface that bends
- **What they are:** lines laid *across* a form, following its surface like a topographic map. They show where it
  bulges and where it sinks; an outline can't.
- **Spacing shows slope:** close lines = steep (turning away from you); wide lines = flat (facing you).
- **On a dent:**
  - the cross-contours bow toward the dent's lowest point;
  - near it they become small nested rings, closing up faster and faster (steeper);
  - lines across the dent (radials) run into it, like the seams of a tunnel.
- **This is the subway tunnel seen end-on.** The dent's lowest point is the tunnel's VP: the rings are the tunnel's
  rings, the radials its seams.
- **Hatching that follows the cross-contours** shades the form and describes it at once (Eurographics: hatching
  "that follows a surface" conveys curvature and foreshortening).

### 2.5 Marks: how a pencil builds a shape
- **Construction first, light:** long, fast lines (ghosted, then drawn in one movement), extended past their corners
  and aimed at the VP. They stay visible, as in references 2 and 3.
- **Edges by accumulation:** 2-4 strokes laid near one another, each slightly off. The edge is where the marks pile
  up most, not one clean line.
- **Line weight:**
  - heavier on the near side, on the side away from the light, at overlaps and on the silhouette;
  - lighter for inner lines and far edges.
  - A drawing in one weight reads flat and doesn't tell the eye where to look.
- **Tone is made of lines:**
  - hatching: parallel strokes; darker = closer together, more pressure or a softer lead;
  - cross-hatching: a second layer near 90°, more angle for darker;
  - contour hatching: strokes following the cross-contours;
  - one hatching direction per plane, as in reference 2.
- **No solid fills.** The darkest darks are dense cross-hatching or scribble. The paper shows through, and the pencil
  has grain (graphite on paper tooth).

### 2.6 Keeping two forms distinct
- **Overlap:** the front form's contour runs unbroken over the back form's lines, which stop at it (T-junctions).
- **Weight:** the front form's silhouette is the heaviest line in the picture.
- **Value:** give the two forms opposite values. Here the fist is dark (cross-hatched) and the torso light (cross-contour
  lines on paper), so they can't fuse.
- **A thin gap:** a sliver of bare paper along the front form's edge where it crosses the back form.
- **Their own marks:** each form's hatching runs in its own direction (the fist along its length, the torso round the
  dent).

### 2.7 Impact drawing (anime and comic practice)
- **Duration and form:** one or a few high-contrast frames at contact, distorted, then snapping back to normal.
- **The hit form deforms; the hitting form holds:** the fist stays solid while the target bends, sinks and stretches.
- **Exaggerated perspective** concentrates force: lines converge hard on the contact, so the contact becomes the VP.
- **Smears and multiples** carry the motion between frames.

## 3. How this applies to the second impact frame
1. **The contact point is the VP of the dent.** The torso is drawn in plain two-point perspective as a box, except
   near the contact. There its cross-contour lines (horizontals and verticals across the chest) bow inward toward the
   VP, and around it nested rings shrink and close up toward the centre, with radial seams running in: the subway
   tunnel, seen end-on.
2. **The torso bends; the fist barely moves.** Each frame the dent deepens: the rings tighten toward the centre, the
   bow of the lines grows, and the radials lengthen. The fist moves only a few pixels.
3. **The fist lands on the dent's VP** (corrected in section 4: its edges run to the VP of its own direction, which the
   torso shares). It is short, dark and cross-hatched along its length, with the heaviest contour in the picture and
   a paper gap where it crosses the torso.
4. **Everything is pencil marks:**
   - light construction lines to the VPs first, left in;
   - edges built from 2-4 strokes;
   - tone from hatching that follows the surface (rings on the torso, lengthwise on the fist);
   - graphite grain;
   - no flat fills, no outlined polygons.
5. **Composition:** one point controls the picture. Everything leads to the contact.

## 4. Second round: "the perspective is off, they are just lined up together"

The first redraw had the right marks, but the torso was drawn nearly flat-on with no top face. The fist had a
vanishing point of its own, so the two read as flat shapes side by side. The user sent six more references:
- tetris pieces in isometric view;
- a 3D tetris pile;
- isometric tetris blocks;
- a bean shape with cross-contours ("curves need to accelerate as they approach the edge", "overshoot curves");
- a room sketch with the important edges marked;
- boxes in two-point perspective ("Align" / "Don't align").

What they teach:
1. **One space for every object.** All the blocks share the same vanishing points. Each object is constructed from
   them by intersecting lines, and every corner sits on lines to the shared vanishing points.
2. **A three-quarter view from above shows three faces** (a top and two sides). Put the horizon above the objects;
   adding a third vanishing point far below for the verticals adds the look-down. A face-on box with no top face reads
   as a flat card.
3. **A block square to another block's face runs its long edges to that block's other vanishing point.** The fist,
   square to the chest, goes to the vanishing point of the torso's side edges. (This replaces 3.3 above: the fist
   doesn't aim at the dent's own point; it lands on it.)
4. **Separate objects must not line up by accident.** Corners or edges of different objects that coincide or continue
   one another (tangents) flatten the depth. Overlap clearly and offset them.
5. **Cross-contours on curved forms** stay calm across the middle and bend faster as they near the edge, then
   overshoot it. On a box they wrap round its corner, turning from one face onto the next toward that face's vanishing
   point.
6. **Line weight goes where planes turn** (the near vertical corner, a ceiling meeting a wall, the front of a step)
   and on the near silhouette. Everything else stays light.

Applied in `design/vfx/impact/build_plunge.ps1`:
- **The perspective:** two-point from above (vanishing points at (-2400,-500) and (2050,-500)) plus a third far below
  at (620,3600).
- **The torso:** constructed from its near top corner, centred and close, with its top, chest and side showing.
- **The fist:** its end square on the chest round the contact, its edges to the right vanishing point.
- **Cross-contours:** they turn at the near corner, and the heavy line runs down that corner.

## Sources
- [Curvilinear perspective (Wikipedia)](https://en.wikipedia.org/wiki/Curvilinear_perspective); [Fish-eye perspective with Peter Han (Proko)](https://www.proko.com/lesson/fish-eye-perspective-with-peter-han); [5-point perspective](https://www.inkl.com/news/how-to-draw-5-point-perspective)
- [Cross-contour lines (Fiveable)](https://fiveable.me/drawing-foundations/key-terms/cross-contour-lines); [Construction drawing and cross contour (Rebelle Art School)](https://www.escapemotions.com/blog/rebelle-art-school-construction-drawing-and-cross-contour); [Hatching that follows a surface (Eurographics paper)](https://diglib.eg.org/bitstream/handle/10.2312/exp20191082/111-121.pdf); [Cross contour on organic forms (Proko)](https://www.proko.com/course-lesson/project-cross-contour-on-organic-forms)
- [How to draw cylinders and ellipses (Proko)](https://www.proko.com/course-lesson/how-to-draw-cylinders-and-ellipses); [Ellipse construction in perspective (Proko forum)](https://www.proko.com/community/topics/ellipse-construction-in-perspective); [Circles and squares in perspective (Drawabox)](https://drawabox.com/r/artfundamentals/post/sqmja0)
- [Linear shading](https://sibleyfineart.com/draw-with-mike-videos/ds008-linear-shading.htm); [Cross hatching for beginners](https://chriswilsonstudio.com/cross-hatching-for-beginners/); [Line, shading, value](https://letslearntogether.neocities.org/art/lines-shading-value)
- [One-point perspective (LibreTexts)](https://human.libretexts.org/Courses/Coalinga_College/Drawing_Perspectives/04%3A_Linear_Perspective/4.03%3A_One-Point_Perspective); [Drawing repeating elements in perspective](https://www.goodreads.com/author_blog_posts/25980965-how-to-draw-repeating-elements-in-perfect-perspective-without-a-ruler)
- [Demon Slayer visual grammar (impact frames)](https://jbsiraudin.github.io/blog/demon-slayer-visual-grammar); [Smear frames](https://blog.cg-wire.com/smear-frames/)
