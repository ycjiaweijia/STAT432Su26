// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#import "@preview/theorion:0.4.1": make-frame

// Simple theorem render: bold title with period, italic body
#let simple-theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  emph(body)
  parbreak()
}
#let (example-counter, example-box, example, show-example) = make-frame(
  "example",
  text(weight: "bold")[Example],
  inherited-levels: theorem-inherited-levels,
  numbering: theorem-numbering,
  render: simple-theorem-render,
)
#show: show-example
#let (definition-counter, definition-box, definition, show-definition) = make-frame(
  "definition",
  text(weight: "bold")[Definition],
  inherited-levels: theorem-inherited-levels,
  numbering: theorem-numbering,
  render: simple-theorem-render,
)
#show: show-definition
#let (proposition-counter, proposition-box, proposition, show-proposition) = make-frame(
  "proposition",
  text(weight: "bold")[Proposition],
  inherited-levels: theorem-inherited-levels,
  numbering: theorem-numbering,
  render: simple-theorem-render,
)
#show: show-proposition
#let (theorem-counter, theorem-box, theorem, show-theorem) = make-frame(
  "theorem",
  text(weight: "bold")[Theorem],
  inherited-levels: theorem-inherited-levels,
  numbering: theorem-numbering,
  render: simple-theorem-render,
)
#show: show-theorem
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Statistical Learning],
  author: "Weijia Jia",
  date: "2026-06-01",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
These are notes for STAT 432 2026 Summer at UIUC. If you have any questions please contact me.

#heading(level: 2, numbering: none)[References]
<references>
#block[
] <refs>
#part[Statistical learning Basics]
= Statistical Learning Basics
<statistical-learning-basics-1>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
== Introduction
<introduction>
Statistical learning studies how to use data to understand relationships and make predictions.

In supervised learning, a common abstract model is

$ Y = f \( X \) + epsilon \, $

where:

- $X$ represents features;
- $Y$ represents the response;
- $f$ is the underlying relationship;
- $epsilon$ represents random noise or unexplained variation.

The main objective is to estimate the unknown function $f$ using observed data.

More broadly, modern statistical learning is fundamentally about learning patterns that generalize well to unseen data.

Depending on the objective, statistical learning problems can be viewed from several different perspectives.

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Task], [Main Question],),
  table.hline(),
  [Prediction], [What will happen?],
  [Inference], [Which variables matter?],
  [Causality], [What happens if we intervene?],
)
- Prediction mainly focuses on predictive performance and generalization. A common formulation is $ hat(f) \( x \) approx bb(E) \[ Y divides X = x \] . $
- Inference focuses on understanding relationships between variables and often relies on tools such as confidence intervals and hypothesis testing.
- Causality studies intervention effects and is often written as $ bb(E) \[ Y divides upright("do") \( X = x \) \] . $

#block[
#callout(
body: 
[
+ Good training performance does not imply good generalization.
+ Good prediction does not imply valid inference.
+ Association does not imply causation.

]
, 
title: 
[
Important distinctions
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
In this course, we will primarily focus on #strong[prediction] and #strong[generalization] rather than formal statistical inference.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
== Types of Learning
<types-of-learning>
Statistical learning problems can be divided into several major categories depending on the available data and learning objective.

We will mainly focus on supervised learning in this course, with some topics from unsupervised learning.

=== Supervised Learning
<supervised-learning>
In supervised learning, we observe both predictors $X$ and response $Y$.

The goal is to predict or explain the response, such as house price prediction, spam detection, medical diagnosis, etc..

Supervised learning is usually divided into two major tasks:

- #strong[regression], where the response is quantitative;
- #strong[classification], where the response is categorical.

#example()[
~

- predicting salary is a regression problem;
- predicting whether a tumor is benign or malignant is a classification problem.

] <exm->
=== Unsupervised Learning
<unsupervised-learning>
In unsupervised learning, we observe predictors $X$ but no response $Y$.

The goal is to discover hidden structure in the data, such as clustering, dimensionality reduction, embedding learning, etc..

=== Reinforcement Learning
<reinforcement-learning>
In reinforcement learning, an agent interacts with an environment and learns through rewards and penalties, such as robotics, game playing, recommendation systems, etc..

== Types of Data
<types-of-data>
Machine learning methods are strongly connected to data structure, and different data types often require different modeling strategies.

This course mainly focuses on #strong[tabular data], which is the classical setting in statistics and applied machine learning.

=== Tabular Data
<tabular-data>
Tabular data is one of the most common data formats in statistical learning. It is typically represented as

$ X in bb(R)^(n times p) \, $

where:

- $n$ is the number of observations;
- $p$ is the number of predictors.

Example:

#table(
  columns: 5,
  align: (right,right,right,center,center,),
  table.header([Age], [Income], [Balance], [Student], [Default],),
  table.hline(),
  [23], [50000], [1200], [Yes], [No],
  [45], [90000], [3000], [No], [Yes],
)
In tabular data:

- rows represent observations;
- columns represent variables or features.

For supervised learning, datasets usually contain:

- a feature matrix $X$\;
- a target variable $y$.

For unsupervised learning, we typically observe only the feature matrix $X$.

Since this course mainly focuses on tabular data, we will usually treat:

$ X in bb(R)^(n times p) \, #h(2em) y in bb(R)^n . $

#block[
#callout(
body: 
[
The key feature of tabular data is NOT merely the matrix representation. More importantly, each column corresponds to a variable with its own semantic meaning, such as age, income, blood pressure, or transaction count.

]
, 
title: 
[
columns correspond to variables
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Tabular data is particularly well suited for methods such as linear models and tree-based models. Therefore, these model families will be the main focus of this course.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Other Types of Data
<other-types-of-data>
Besides tabular data, many machine learning problems involve other data formats. We briefly mention several common examples that appear in modern learning tasks.

#block[
#callout(
body: 
[
Image data contains spatial structure, meaning nearby pixels are highly related.

Modern image models frequently use:

- convolutional neural networks,
- vision transformers.

A central goal is to extract meaningful visual patterns such as edges, textures, shapes, and objects.

]
, 
title: 
[
Image Data
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Text data contains sequential and contextual structure. Modern NLP is largely based on transformers and large language models.

]
, 
title: 
[
Text Data
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Time series data is ordered over time such as stock prices, weather data and sensor measurements.

]
, 
title: 
[
Time Series Data
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Graph data represents relationships between objects, such as social networks, citation networks, molecular structures.

Modern graph learning often uses graph neural networks.

]
, 
title: 
[
Graph Data
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Generalization and Model Complexity
<generalization-and-model-complexity>
=== Training Error and Test Error
<training-error-and-test-error>
Classical regression focuses heavily on checking model assumptions, such as independence of errors, constant variance, approximate normality. These assumptions are especially important for formal inference, including confidence intervals and hypothesis testing.

In statistical learning, however, the primary goal is often #strong[predictive performance] rather than formal inference. As a result, diagnostic tools still remain useful, but they usually play a secondary role. Their main purpose is often to detect serious issues such as strong nonlinearity, influential observations, data quality problems, severe model misspecification.

The central question becomes: How well does the model predict new observations?

#definition(title: [Training Error and Test Error])[
~

- The training error measures how well a model fits the training data.
- The test error measures prediction error on new observations not used to fit the model.

] <def-training-error>
For example, suppose we evaluate a regression model using mean squared error (MSE).

The #strong[training MSE] measures fit on the observed training sample, while the #strong[test MSE] measures prediction performance on new data drawn from the same population.

A model may achieve extremely small training error while still performing poorly on unseen data. This happens because the model begins fitting random noise rather than the underlying signal.

#definition(title: [Overfitting])[
Overfitting occurs when a model fits the training data very closely but fails to generalize well to new data. In this case, the model captures random noise or idiosyncrasies in the training sample rather than the underlying relationship.

] <def-overfitting>
Model selection methods attempt to balance model complexity and prediction accuracy in order to avoid overfitting.

=== Bias--Variance Tradeoff
<biasvariance-tradeoff>
A central idea behind generalization is the #strong[bias--variance tradeoff].

Suppose

$ Y = f \( X \) + epsilon \, #h(2em) "Var" \( epsilon \) = sigma^2 . $

For a fitted estimator $hat(f)$, the test mean squared error at $x_0$ satisfies

\$\$
\\operatorname{E}\\qty\[(Y\_0-\\hat f(x\_0))^2\]=
\\operatorname{Bias}^2(\\hat f(x\_0))
+
\\operatorname{Var}(\\hat f(x\_0))
+
\\sigma^2.
\$\$

The three terms represent:

- #strong[bias]: systematic modeling error: $"Bias" \( hat(f) \( x \) \) = "E" \[ hat(f) \( x \) \] - f \( x \)$. It measures the systematic difference between the average prediction and the true underlying function;
- #strong[variance]: sensitivity to the training sample: $"Var" \( hat(f) \( x \) \)$. It measures how much the fitted model changes when the training data changes. Highly flexible models often have larger variance;
- #strong[irreducible error]: $sigma^2$. This represents random noise or variability in the data generation process that cannot be explained or removed, even with the true model.

Roughly speaking, as model flexibility increases:

- training error usually decreases;
- test error often first decreases and then increases.

Model selection aims to balance these two effects in order to achieve good generalization performance.

#block[
#callout(
body: 
[
Many modern methods can be viewed as ways to control the bias--variance tradeoff. Regularization, cross-validation, ensemble methods, trees, boosting, and neural networks can all be understood from this perspective.

]
, 
title: 
[
Main Point
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Classical regression often estimates expected test error indirectly using only the training data.

Some commonly used criteria are:

- AIC (Akaike Information Criterion),
- BIC (Bayesian Information Criterion),
- Mallows' $C_p$.

These criteria reward good fit while penalizing excessive model complexity.

Although they are useful for model comparison, they still rely on approximations derived from the training sample.

]
, 
title: 
[
Information Criteria and Estimated Test Error
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= Classification Decisions and Evaluation
<classification-decisions-and-evaluation>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
Unlike regression, where metrics such as Mean Squared Error (MSE) evaluate prediction error along a continuous scale, classification evaluation is fundamentally more nuanced.

A modern statistical learning classifier often produces a score or estimated probability rather than directly outputting a categorical decision. For example, a model may estimate

$ hat(p) \( x \) = Pr \( Y = 1 divides X = x \) \, $

and a separate decision rule then converts this soft prediction into a hard classification. As a result, classification performance can be evaluated from several different perspectives.

Broadly speaking, classification evaluation can be divided into three related but distinct goals.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Goal], [Main question], [Common tools],),
  table.hline(),
  [Decision quality], [Are the final classification decisions good?], [Accuracy, precision, recall, F1-score],
  [Ranking quality], [Are positive observations ranked above negative observations?], [ROC curve, AUC, PR curve],
  [Probability quality], [Are predicted probabilities numerically trustworthy?], [Calibration curve, Brier score, log loss],
)
These goals are related but fundamentally different. Accurate probability estimates are the richest output: they can support ranking and threshold-based decisions. However, good decisions, good rankings, and calibrated probabilities are different evaluation goals and one does not generally imply the others.

If a model accurately estimates the true conditional probability distribution $Pr \( Y divides X \)$, then it naturally induces good rankings and supports effective decision-making across many possible thresholds or cost functions. However, the converse implications generally fail. Optimizing only a threshold-based metric such as accuracy provides no guarantee that the underlying probabilities are calibrated or that the ranking behavior is reliable.

In practice, however, decision quality is often easier to achieve and is frequently the primary objective in applied statistical learning. Many real-world applications ultimately require concrete actions, such as approving a loan, detecting fraud, or diagnosing disease. Consequently, threshold-based metrics such as accuracy, precision, recall, and F1-score often play the central role in applied machine learning.

#block[
#callout(
body: 
[
Classification evaluation can become quite sophisticated and may involve ranking performance, probability calibration, cost-sensitive learning, threshold optimization, and decision theory.

In this course, however, our primary goal is to understand the core ideas of statistical learning and predictive modeling rather than to develop a complete theory of statistical decision making. Therefore, we will mainly focus on accuracy and closely related threshold-based classification metrics.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Decision quality
<decision-quality>
Decision quality evaluates the final hard classifications after applying a threshold to predicted scores or probabilities.

This perspective focuses on whether the model makes useful decisions in practice. Metrics such as accuracy, precision, recall, and F1-score belong to this category.

=== Binary Classification Setup
<binary-classification-setup>
Suppose the response is binary:

$ Y in { 0 \, 1 } . $

We call $Y = 1$ the positive class and $Y = 0$ the negative class.

A classifier produces a predicted label

$ hat(Y) in { 0 \, 1 } . $

The four possible outcomes are summarized by the confusion matrix.

#table(
  columns: 3,
  align: (auto,right,right,),
  table.header([], [Predicted positive], [Predicted negative],),
  table.hline(),
  [True positive class], [TP], [FN],
  [True negative class], [FP], [TN],
)
Here, TP means true positive, FP means false positive, FN means false negative, TN means true negative.

The confusion matrix is the starting point for most threshold-based classification metrics.

=== Accuracy
<accuracy>
Accuracy is the proportion of correctly classified observations:

$ upright("Accuracy") = frac(T P + T N, T P + F P + F N + T N) . $

Accuracy is simple and useful when:

- the classes are reasonably balanced,
- false positives and false negatives have similar costs,
- the decision threshold is already fixed and meaningful.

However, accuracy can be misleading.

Suppose only $1 %$ of observations are positive. A classifier that always predicts negative has $99 %$ accuracy, but it never detects a positive case. In many applications, that classifier is useless.

#block[
#callout(
body: 
[
Accuracy implicitly treats all mistakes as equally costly.

When classes are imbalanced or error costs are asymmetric, accuracy can hide the most important behavior of the classifier.

]
, 
title: 
[
Accuracy is not enough
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
=== Recall (sensitivity)
<recall-sensitivity>
Recall is defined as

$ upright("Recall") = frac(T P, T P + F N) . $

Recall answers the question:

#quote(block: true)[
Among all truly positive observations, how many did we detect?
]

In probability notation,

$ upright("Recall") = P \( hat(Y) = 1 divides Y = 1 \) . $

Recall is also called sensitivity, or true positive rate (TPR).

High recall means few false negatives. Low recall means many true positive cases were missed.

#block[
#callout(
body: 
[
Recall has a direct connection to hypothesis testing.

Suppose we think of the classification problem as testing

$ H_0 : Y = 0 quad upright("versus") quad H_1 : Y = 1 . $

Predicting positive is like rejecting $H_0$. Predicting negative is like failing to reject $H_0$.

Under this interpretation:

- a false positive is a Type I error,
- a false negative is a Type II error,
- recall plays a role analogous to statistical power.

Thus

$ upright("Recall") = 1 - upright("Type II error rate") . $

Recall measures the ability to detect true signals.

]
, 
title: 
[
Recall and Statistical Power
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Precision
<precision>
Precision is defined as

$ upright("Precision") = frac(T P, T P + F P) . $

Precision answers the question:

#quote(block: true)[
Among all observations predicted positive, how many are truly positive?
]

In probability notation,

$ upright("Precision") = P \( Y = 1 divides hat(Y) = 1 \) . $

Precision is also called positive predictive value.

High precision means positive predictions are trustworthy. Low precision means many predicted positives are false alarms.

#block[
#callout(
body: 
[
Precision and recall condition on different events.

Recall conditions on the truth:

$ P \( hat(Y) = 1 divides Y = 1 \) . $

Precision conditions on the prediction:

$ P \( Y = 1 divides hat(Y) = 1 \) . $

This distinction is very important.

Recall asks whether we find the positives. Precision asks whether our positive discoveries are reliable. Precision depends strongly on class prevalence.

]
, 
title: 
[
Precision vs Recall
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== F1 Score
<f1-score>
The F1 score combines precision and recall:

$ F_1 = frac(2 P R, P + R) \, $

where $P$ is precision and $R$ is recall.

Equivalently,

$ F_1 = frac(2 T P, 2 T P + F P + F N) . $

The F1 score is the harmonic mean of precision and recall.

The harmonic mean strongly penalizes imbalance. If precision is high but recall is near zero, then F1 is near zero. If recall is high but precision is near zero, then F1 is also near zero.

F1 is useful when we want a single number that balances precision and recall. However, it assumes precision and recall are equally important. In applications where one type of error is more costly, a different metric or an explicit cost function may be better.

#block[
#callout(
body: 
[
F1 ignores true negatives entirely.

This can be useful for rare event detection, where the number of true negatives may dominate the dataset and make accuracy misleading.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Recall vs Precision
<recall-vs-precision>
==== Bayes' Rule and Class Imbalance
<bayes-rule-and-class-imbalance>
Precision and recall are connected by Bayes' rule.

Let $pi = P \( Y = 1 \)$ be the prevalence of the positive class.

#proposition()[
$ upright("Precision") = P \( Y = 1 divides hat(Y) = 1 \) = frac(T P R dot.op pi, T P R dot.op pi + F P R \( 1 - pi \)) . $

This formula shows why precision can be low for rare events: when $pi$ is small, even a modest false positive rate can create many false positives.

Click to expand.
Let

$ T P R = P \( hat(Y) = 1 divides Y = 1 \) = upright("Recall") $

and

$ F P R = P \( hat(Y) = 1 divides Y = 0 \) . $

Then by Bayes' Rule,

$ upright("Precision") = & P \( Y = 1 divides hat(Y) = 1 \)\
= & frac(P \( hat(Y) = 1 divides Y = 1 \) P \( Y = 1 \), P \( hat(Y) = 1 divides Y = 1 \) P \( Y = 1 \) + P \( hat(Y) = 1 divides Y = 0 \) P \( Y = 0 \))\
= & frac(T P R dot.op pi, T P R dot.op pi + F P R dot.op \( 1 - pi \)) . $

] <prp->
#example(title: [Rare Event Example])[
~

Click to expand.
Suppose there are 10,000 observations:

- 100 positives,
- 9,900 negatives.

Assume the classifier has:

$ T P R = 0.90 \, quad F P R = 0.05 . $

Then:

$ T P = 90 \, quad F P = 495 . $

The recall is high:

$ upright("Recall") = 0.90 . $

But precision is only

$ upright("Precision") = frac(90, 90 + 495) approx 0.154 . $

Most predicted positives are false positives. This is why precision-recall analysis is especially important for imbalanced data.
] <exm->
==== Classification Thresholds
<classification-thresholds>
Many classifiers first produce a score or estimated probability:

$ hat(p) \( x \) = P \( Y = 1 divides X = x \) . $

To make a hard classification, we choose a threshold $c$:

$ hat(Y) = cases(delim: "{", 1 \, & hat(p) \( x \) > c \,, 0 \, & hat(p) \( x \) lt.eq c .) $

The default decision threshold is often $c = 0.5$, but this is not always the optimal choice. Changing the threshold changes the confusion matrix, and therefore also changes metrics such as accuracy, precision, recall, false positive rate (FPR), and F1 score.

To better understand the precision--recall tradeoff, let us examine how altering the decision threshold changes the behavior of a classifier.

#table(
  columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
  align: (auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header([Decision Threshold], [TP], [TN], [FP], [FN], [Recall], [Precision], [Classifier Behavior],),
  table.hline(),
  [Lower threshold], [Non-decreasing], [Non-increasing], [Non-decreasing], [Non-increasing], [Non-decreasing], [May decrease], [],
  [Higher threshold], [Non-increasing], [Non-decreasing], [Non-increasing], [Non-decreasing], [Non-increasing], [May increase], [],
)
Lowering the threshold classifies more observations as positive. Therefore, both true positives (TP) and false positives (FP) may increase, while false negatives (FN) decrease.

Raising the threshold classifies more observations as negative. Therefore, both true negatives (TN) and false negatives (FN) may increase, while true positives (TP) decrease.

#example(title: [Example: Precision Is Not Strictly Monotone])[
~

Click to expand.
Consider a small validation dataset with five observations. The model outputs predicted probabilities $hat(P) \( Y = 1 divides X \)$, ordered from highest to lowest.

#table(
  columns: 3,
  align: (center,right,center,),
  table.header([Instance], [Predicted Probability], [True Label],),
  table.hline(),
  [A], [0.95], [1],
  [B], [0.90], [0],
  [C], [0.85], [1],
  [D], [0.80], [1],
  [E], [0.70], [0],
)
As the threshold is raised, fewer observations are classified as positive.

#table(
  columns: 5,
  align: (right,auto,right,right,right,),
  table.header([Threshold], [Predicted Positives], [TP], [FP], [Precision],),
  table.hline(),
  [0.75], [A, B, C, D], [3], [1], [$3 \/ 4 = 0.75$],
  [0.82], [A, B, C], [2], [1], [$2 \/ 3 approx 0.67$],
  [0.88], [A, B], [1], [1], [$1 \/ 2 = 0.50$],
  [0.92], [A], [1], [0], [$1 \/ 1 = 1.00$],
)
In this example, raising the threshold first decreases precision because some true positives are removed while the false positive remains. Precision increases only after the false positive is also removed.

This shows that precision can move up or down as the threshold changes, depending on the labels of the observations crossing the threshold.

] <exm->
#block[
#callout(
body: 
[
- The fitted model may estimate probabilities.
- The threshold determines the action.

Model fitting and decision making are related, but they are not the same thing.

]
, 
title: 
[
Thresholds are decisions
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
==== Decision Theory and Error Costs
<decision-theory-and-error-costs>
Suppose a false positive has cost $C_(F P)$ and a false negative has cost $C_(F N)$.

If a model estimates

$ p \( x \) = P \( Y = 1 divides X = x \) \, $

then the expected cost of predicting positive is

$ upright("Cost") \( 1 divides x \) = C_(F P) P \( Y = 0 divides X = x \) = C_(F P) \( 1 - p \( x \) \) . $

The expected cost of predicting negative is

$ upright("Cost") \( 0 divides x \) = C_(F N) P \( Y = 1 divides X = x \) = C_(F N) p \( x \) . $

We should predict positive when

$ C_(F P) \( 1 - p \( x \) \) < C_(F N) p \( x \) . $

Solving this inequality gives

$ p \( x \) > frac(C_(F P), C_(F P) + C_(F N)) . $

Thus the optimal threshold is

$ c^(*) = frac(C_(F P), C_(F P) + C_(F N)) . $

This threshold minimizes the expected classification cost under the assumed probability model.

If false negatives are very costly, then $C_(F N)$ becomes large, which lowers the threshold. In this case, the classifier predicts the positive class more aggressively in order to reduce missed detections.

#example(title: [Medical Screening])[
In medical screening, missing a serious disease may be much worse than sending a healthy patient for an additional test. Therefore false negatives are costly.

The threshold should often be lower, so the classifier prioritizes recall.

] <exm->
#example(title: [Spam Filtering])[
In spam filtering, putting an important legitimate email into spam may be very costly to the user. Therefore false positives may be more costly.

The threshold should often be higher, so the classifier prioritizes precision.

] <exm->
== Ranking quality
<ranking-quality>
Ranking quality evaluates whether positive observations tend to receive higher scores than negative observations.

This perspective is important when the classification threshold is not fixed or when the main goal is prioritization rather than direct classification. ROC curves, AUC, and precision--recall curves are commonly used to evaluate ranking performance.

=== ROC
<roc>
ROC stands for receiver operating characteristic. An ROC curve plots: $ T P R = frac(T P, T P + F N) quad upright(" against ") quad F P R = frac(F P, F P + T N) $ as the probability threshold varies from 0 to 1.

=== ROC and Hypothesis Testing
<roc-and-hypothesis-testing>
ROC curves have a natural hypothesis testing interpretation. As discussed before,

- TPR is power,
- FPR is Type I error rate.

Therefore an ROC curve shows

$ upright("power") quad upright("versus") quad upright("Type I error rate") $

across all possible thresholds.

The ideal classifier reaches the upper-left corner:

$ F P R = 0 \, quad T P R = 1 . $

A classifier close to the diagonal line behaves almost like random guessing.

=== AUC
<auc>
AUC refers to the Area Under the ROC Curve. It summarizes ranking performance across all possible classification thresholds.

Let $s \( X^(+) \)$ be the score for a randomly selected positive observation, and let $s \( X^(-) \)$ be the score for a randomly selected negative observation. Then

$ A U C = P (s \( X^(+) \) > s \( X^(-) \)) \, $

up to small corrections for ties.

Thus AUC has a clean probabilistic interpretation:

#quote(block: true)[
AUC is the probability that a randomly selected positive observation receives a higher score than a randomly selected negative observation.
]

This explains why AUC is threshold-free. It evaluates ranking quality rather than the quality of a particular classification decision.

Importantly, AUC evaluates relative ordering rather than absolute probability accuracy.

#block[
#callout(
body: 
[
AUC can be excellent even when predicted probabilities are numerically inaccurate.

AUC only asks whether positive observations tend to receive higher scores than negative observations. It does not ask whether the predicted probabilities themselves are trustworthy or well calibrated.

]
, 
title: 
[
AUC is not calibration
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
=== Precision-Recall Curve
<precision-recall-curve>
A precision-recall curve plots precision against recall as the classification threshold changes.

It is especially useful when the positive class is rare. In imbalanced datasets, an ROC curve may look strong because the false positive rate is divided by the large number of true negatives. However, precision directly measures how many predicted positives are actually positive.

Average precision summarizes the precision-recall curve as a single number. Like AUC, it evaluates ranking behavior across thresholds, but it focuses more directly on performance for the positive class.

== Probability Quality
<probability-quality>
Probability quality asks whether predicted probabilities can be interpreted as actual probabilities.

For example, suppose a model predicts $hat(p) \( x \) = 0.8$. If the model is well calibrated, then among many observations with predicted probability near $0.8$, roughly $80 %$ should truly belong to the positive class.

Thus probability quality concerns whether predicted probabilities are numerically trustworthy.

Unlike decision quality or ranking quality, probability quality focuses on the accuracy of the probability estimates themselves. Calibration curves, Brier score, and log loss are commonly used to evaluate probability quality.

#block[
#callout(
body: 
[
In many practical machine learning applications, probability quality is less important than classification accuracy or ranking performance.

Therefore, in this course, we will mainly focus on threshold-based classification metrics such as accuracy, precision, recall, and F1 score. This section is included primarily to provide a broader view of classification evaluation.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Calibration Curve
<calibration-curve>
A calibration curve, also called a reliability diagram, is constructed as follows:

+ Divide observations into bins according to predicted probability.
+ For each bin, compute the average predicted probability.
+ Compute the observed positive proportion in each bin.
+ Plot observed proportion against average predicted probability.

For a perfectly calibrated model, the curve follows the diagonal line.

- If the curve lies below the diagonal, the model is overconfident.
- If the curve lies above the diagonal, the model is underconfident.

== Model Tuning versus Threshold Tuning
<model-tuning-versus-threshold-tuning>
In classification, model fitting and decision making should be viewed as separate problems.

First, the model estimates a score or probability:

$ hat(p) \( x \) approx Pr \( Y = 1 divides X = x \) . $

Second, we choose a threshold to convert this probability into an action.

Model tuning affects the quality of $hat(p) \( x \)$ itself. This is where ideas such as bias, variance, regularization, and model complexity matter. A very flexible classifier may capture nonlinear structure, but its probability estimates may be unstable or poorly calibrated.

Threshold tuning does not change $hat(p) \( x \)$. It only changes the decision rule built on top of the fitted probabilities. Lower thresholds usually increase recall and false positives; higher thresholds usually increase precision and reduce false positives.

Thus:

- model tuning controls the fitted scores or probabilities;
- threshold tuning controls the action taken from those scores;
- calibration checks whether the probabilities are numerically trustworthy.

A good classifier therefore involves not only learning accurate scores, but also choosing appropriate decision rules for the application.

== Python Example: Breast Cancer Classification
<python-example-breast-cancer-classification>
We now use the #link("https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_breast_cancer.html")[breast cancer dataset from #NormalTok("sklearn");]. The goal is to classify tumors as malignant or benign. This example shows how to compute threshold-based metrics, ROC and PR curves, and calibration curves.

In this example, please mainly focus on the evaluation metrics. Other part like modeling, splitting, etc. will be introduced in later sections.

=== Load the dataset
<load-the-dataset>
First load the data and split it into training and test sets. By default, the dataset uses #NormalTok("0"); for malignant and #NormalTok("1"); for benign. Since many classification metrics interpret label #NormalTok("1"); as the positive class, we redefine malignant as #NormalTok("1");. Therefore we need to modify the #NormalTok("y"); value.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_breast_cancer");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("cancer ");#OperatorTok("=");#NormalTok(" load_breast_cancer(as_frame");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" cancer.data");],
[#NormalTok("y_original ");#OperatorTok("=");#NormalTok(" cancer.target");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" y_original");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", stratify");#OperatorTok("=");#NormalTok("y, random_state");#OperatorTok("=");#DecValTok("1");],
[#NormalTok(")");],));
]
We may want to see the distribution of the test set.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#NormalTok("pd.Series(y_test).value_counts().sort_index()");],));
#Skylighting(([#NormalTok("target");],
[#NormalTok("0    107");],
[#NormalTok("1     64");],
[#NormalTok("Name: count, dtype: int64");],));
=== Fit models
<fit-models>
We fit logistic regression model as an example, which is a typical strong baseline model.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" make_pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LogisticRegression");],
[],
[#NormalTok("logit ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LogisticRegression(max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok(")");],
[],
[#NormalTok("logit.fit(X_train, y_train)");],
[],
[#NormalTok("logit_prob ");#OperatorTok("=");#NormalTok(" logit.predict_proba(X_test)[:, ");#DecValTok("1");#NormalTok("]");],));
]
Note that #NormalTok("logit.predict_proba(X_test)"); returns 2 columns:

- column 0: $Pr \( Y = 0 divides X \)$,
- column 1: $Pr \( Y = 1 divides X \)$.

Since we want the predicted probability for the positive class (#NormalTok("y=1");), we select the second column.

=== Confusion Matrix and Basic Metrics
<confusion-matrix-and-basic-metrics>
All decision quality metrics can be computed using functions from #NormalTok("sklearn.metrics");. They are used to compare two list-like objects, while the true labels are passed first and the predicted labels second.

By default, #NormalTok("predict()"); in #NormalTok("sklearn"); uses threshold $0.5$ for binary classification.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" accuracy_score, precision_score, recall_score, f1_score");],
[],
[#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" logit.predict(X_test)");],
[],
[#NormalTok("acc ");#OperatorTok("=");#NormalTok(" accuracy_score(y_test, y_pred)");],
[#NormalTok("prec ");#OperatorTok("=");#NormalTok(" precision_score(y_test, y_pred)");],
[#NormalTok("rec ");#OperatorTok("=");#NormalTok(" recall_score(y_test, y_pred)");],
[#NormalTok("f1 ");#OperatorTok("=");#NormalTok(" f1_score(y_test, y_pred)");],));
]
We can also compute the confusion matrix and extract the values of TP, TN, FP, and FN from it.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" confusion_matrix");],
[],
[#NormalTok("confusion_matrix(y_test, y_pred)");],));
#Skylighting(([#NormalTok("array([[106,   1],");],
[#NormalTok("       [  6,  58]])");],));
#block[
#Skylighting(([#NormalTok("TN, FP, FN, TP ");#OperatorTok("=");#NormalTok(" confusion_matrix(y_test, y_pred).ravel()");],));
]
They are listed in this particular order since 0 stands for negative and 1 stands for positive in this example.

=== Modifying Thresholds
<modifying-thresholds>
The default model use 0.5 as the threshold in #NormalTok("sklearn");. If you want to change the threshold, you may manually write the code.

#block[
#Skylighting(([#NormalTok("threshold ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[#NormalTok("logit_prob ");#OperatorTok("=");#NormalTok(" logit.predict_proba(X_test)[:, ");#DecValTok("1");#NormalTok("] ");],
[#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" (logit_prob ");#OperatorTok(">=");#NormalTok(" threshold).astype(");#BuiltInTok("int");#NormalTok(")");],));
]
You may also use #NormalTok("FixedThresholdClassifier"); from #NormalTok("sklearn.model_selection"); when you want the threshold to be part of the estimator workflow.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" FixedThresholdClassifier");],
[],
[#NormalTok("threshold ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[#NormalTok("model_with_threshold ");#OperatorTok("=");#NormalTok(" FixedThresholdClassifier(");],
[#NormalTok("    make_pipeline(");],
[#NormalTok("        StandardScaler(),");],
[#NormalTok("        LogisticRegression(max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok("    ),");],
[#NormalTok("    threshold");#OperatorTok("=");#NormalTok("threshold,");],
[#NormalTok(")");],
[],
[#NormalTok("model_with_threshold.fit(X_train, y_train)");],
[#NormalTok("y_pred_wrapper ");#OperatorTok("=");#NormalTok(" model_with_threshold.predict(X_test)");],));
]
#block[
#callout(
body: 
[
#NormalTok("FixedThresholdClassifier"); is useful when the threshold is fixed in advance.

However, there might be cases that you want to adjust the threshold according to the dataset. In this case you may want to use #NormalTok("TunedThresholdClassifierCV");. We will talk about it in details later in the Logistic regression section.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Tuning Thresholds
<tuning-thresholds>
In order to make the tuning process easier, we build an interface to quickly display the results.

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" classification_summary(y_true, prob, threshold");#OperatorTok("=");#FloatTok("0.5");#NormalTok("):");],
[#NormalTok("    pred ");#OperatorTok("=");#NormalTok(" (prob ");#OperatorTok(">=");#NormalTok(" threshold).astype(");#BuiltInTok("int");#NormalTok(")");],
[#NormalTok("    TN, FP, FN, TP ");#OperatorTok("=");#NormalTok(" confusion_matrix(y_true, pred).ravel()");],
[],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("        ");#StringTok("\"threshold\"");#NormalTok(": threshold,");],
[#NormalTok("        ");#StringTok("\"TP\"");#NormalTok(": TP,");],
[#NormalTok("        ");#StringTok("\"FP\"");#NormalTok(": FP,");],
[#NormalTok("        ");#StringTok("\"FN\"");#NormalTok(": FN,");],
[#NormalTok("        ");#StringTok("\"TN\"");#NormalTok(": TN,");],
[#NormalTok("        ");#StringTok("\"accuracy\"");#NormalTok(": accuracy_score(y_true, pred),");],
[#NormalTok("        ");#StringTok("\"precision\"");#NormalTok(": precision_score(y_true, pred),");],
[#NormalTok("        ");#StringTok("\"recall\"");#NormalTok(": recall_score(y_true, pred),");],
[#NormalTok("        ");#StringTok("\"f1\"");#NormalTok(": f1_score(y_true, pred),");],
[#NormalTok("    }");],));
]
Now examine how metrics change as the threshold changes. To save space I only show the first few rows of the table.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("thresholds ");#OperatorTok("=");#NormalTok(" np.linspace(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.95");#NormalTok(", ");#DecValTok("19");#NormalTok(")");],
[#NormalTok("threshold_results ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" threshold ");#KeywordTok("in");#NormalTok(" thresholds:");],
[#NormalTok("    row ");#OperatorTok("=");#NormalTok(" classification_summary(y_test, logit_prob, threshold");#OperatorTok("=");#NormalTok("threshold)");],
[#NormalTok("    threshold_results.append(row)");],
[],
[#NormalTok("threshold_df ");#OperatorTok("=");#NormalTok(" pd.DataFrame(threshold_results)");],
[],
[#NormalTok("threshold_df.head()");],));
#table(
  columns: 10,
  align: (auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[threshold], table.cell(align: right)[TP], table.cell(align: right)[FP], table.cell(align: right)[FN], table.cell(align: right)[TN], table.cell(align: right)[accuracy], table.cell(align: right)[precision], table.cell(align: right)[recall], table.cell(align: right)[f1],),
  table.hline(),
  table.cell(align: horizon)[0], [0.05], [62], [8], [2], [99], [0.941520], [0.885714], [0.968750], [0.925373],
  table.cell(align: horizon)[1], [0.10], [61], [7], [3], [100], [0.941520], [0.897059], [0.953125], [0.924242],
  table.cell(align: horizon)[2], [0.15], [60], [5], [4], [102], [0.947368], [0.923077], [0.937500], [0.930233],
  table.cell(align: horizon)[3], [0.20], [60], [5], [4], [102], [0.947368], [0.923077], [0.937500], [0.930233],
  table.cell(align: horizon)[4], [0.25], [60], [4], [4], [103], [0.953216], [0.937500], [0.937500], [0.937500],
)
Plot precision and recall as functions of the threshold.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.plot(threshold_df[");#StringTok("\"threshold\"");#NormalTok("], threshold_df[");#StringTok("\"precision\"");#NormalTok("], marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"precision\"");#NormalTok(")");],
[#NormalTok("plt.plot(threshold_df[");#StringTok("\"threshold\"");#NormalTok("], threshold_df[");#StringTok("\"recall\"");#NormalTok("], marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"recall\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"threshold\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"metric value\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Precision and Recall versus Threshold\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\0/decisioneval_files/figure-typst/cell-12-output-1.svg"))

As the threshold increases, the classifier becomes more conservative in predicting the positive class. This often reduces false positives and increases precision, but may also increase false negatives and reduce recall.

=== Choosing a Threshold from Costs
<choosing-a-threshold-from-costs>
In a medical setting, false negatives may be especially important because they correspond to missed malignant cases. Suppose a false negative is 5 times as costly as a false positive:

$ C_(F N) = 5 \, quad C_(F P) = 1 . $

The decision-theoretic threshold is

$ c^(*) = frac(C_(F P), C_(F P) + C_(F N)) = frac(1, 1 + 5) approx 0.167 . $

Then the corresponding result is

#Skylighting(([#NormalTok("cost_fp ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("cost_fn ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[],
[#NormalTok("cost_threshold ");#OperatorTok("=");#NormalTok(" cost_fp ");#OperatorTok("/");#NormalTok(" (cost_fp ");#OperatorTok("+");#NormalTok(" cost_fn)");],
[],
[#NormalTok("classification_summary(");],
[#NormalTok("    y_test,");],
[#NormalTok("    logit_prob,");],
[#NormalTok("    threshold");#OperatorTok("=");#NormalTok("cost_threshold,");],
[#NormalTok(")");],));
#Skylighting(([#NormalTok("{'threshold': 0.16666666666666666,");],
[#NormalTok(" 'TP': np.int64(60),");],
[#NormalTok(" 'FP': np.int64(5),");],
[#NormalTok(" 'FN': np.int64(4),");],
[#NormalTok(" 'TN': np.int64(102),");],
[#NormalTok(" 'accuracy': 0.9473684210526315,");],
[#NormalTok(" 'precision': 0.9230769230769231,");],
[#NormalTok(" 'recall': 0.9375,");],
[#NormalTok(" 'f1': 0.9302325581395349}");],));
This lower threshold prioritizes recall. It predicts malignant more aggressively because missing a malignant tumor is assumed to be more costly. Note that this threshold formula assumes that the predicted probabilities are reasonably calibrated so that they can be interpreted as approximate event probabilities.

=== ROC Curve and AUC
<roc-curve-and-auc>
Unlike accuracy or precision, ROC analysis does not depend on a single fixed threshold. Instead, it studies model performance across all possible thresholds using the predicted probabilities or scores.

ROC curve and AUC can be computed using #NormalTok("roc_curve"); and #NormalTok("roc_auc_score"); from #NormalTok("sklearn.metrics");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" roc_curve, roc_auc_score");],
[],
[#NormalTok("logit_fpr, logit_tpr, _ ");#OperatorTok("=");#NormalTok(" roc_curve(y_test, logit_prob)");],
[#NormalTok("logit_auc ");#OperatorTok("=");#NormalTok(" roc_auc_score(y_test, logit_prob)");],
[],
[#NormalTok("plt.plot(logit_fpr, logit_tpr, label");#OperatorTok("=");#SpecialStringTok("f\"Logistic regression AUC = ");#SpecialCharTok("{");#NormalTok("logit_auc");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.plot([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], ");#StringTok("\"k--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"random guessing\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"false positive rate\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"true positive rate\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"ROC Curve\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],
[#NormalTok("plt.show()");],));
#box(image("contents\\0/decisioneval_files/figure-typst/cell-14-output-1.svg"))

We may fit another model and draw their ROC curve and AUC together in one plot to compare them.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" RandomForestClassifier");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("500");#NormalTok(", max_features");#OperatorTok("=");#StringTok("\"sqrt\"");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok(")");],
[],
[#NormalTok("rf.fit(X_train, y_train)");],
[#NormalTok("rf_prob ");#OperatorTok("=");#NormalTok(" rf.predict_proba(X_test)[:, ");#DecValTok("1");#NormalTok("]");],
[],
[#NormalTok("rf_fpr, rf_tpr, _ ");#OperatorTok("=");#NormalTok(" roc_curve(y_test, rf_prob)");],
[#NormalTok("rf_auc ");#OperatorTok("=");#NormalTok(" roc_auc_score(y_test, rf_prob)");],
[],
[#NormalTok("plt.plot(logit_fpr, logit_tpr, label");#OperatorTok("=");#SpecialStringTok("f\"Logistic regression AUC = ");#SpecialCharTok("{");#NormalTok("logit_auc");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.plot(rf_fpr, rf_tpr, label");#OperatorTok("=");#SpecialStringTok("f\"Random forest AUC = ");#SpecialCharTok("{");#NormalTok("rf_auc");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.plot([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], ");#StringTok("\"k--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"random guessing\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"false positive rate\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"true positive rate\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"ROC Curve\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\0/decisioneval_files/figure-typst/cell-15-output-1.svg"))

The ROC curve summarizes ranking performance across thresholds. AUC may be interpreted as the probability that a randomly chosen positive observation receives a higher score than a randomly chosen negative observation. Then a larger AUC means the model more often ranks malignant cases above benign cases.

=== Precision-Recall Curve
<precision-recall-curve-1>
The precision-recall curve can be produced in a similar way.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" precision_recall_curve, average_precision_score");],
[],
[#NormalTok("logit_precision, logit_recall, _ ");#OperatorTok("=");#NormalTok(" precision_recall_curve(y_test, logit_prob)");],
[#NormalTok("rf_precision, rf_recall, _ ");#OperatorTok("=");#NormalTok(" precision_recall_curve(y_test, rf_prob)");],
[],
[#NormalTok("logit_ap ");#OperatorTok("=");#NormalTok(" average_precision_score(y_test, logit_prob)");],
[#NormalTok("rf_ap ");#OperatorTok("=");#NormalTok(" average_precision_score(y_test, rf_prob)");],
[],
[#NormalTok("plt.plot(logit_recall, logit_precision, label");#OperatorTok("=");#SpecialStringTok("f\"Logistic regression AP = ");#SpecialCharTok("{");#NormalTok("logit_ap");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.plot(rf_recall, rf_precision, label");#OperatorTok("=");#SpecialStringTok("f\"Random forest AP = ");#SpecialCharTok("{");#NormalTok("rf_ap");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"recall\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"precision\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Precision-Recall Curve\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\0/decisioneval_files/figure-typst/cell-16-output-1.svg"))

For highly imbalanced datasets, precision--recall curves are often more informative than ROC curves because ROC curves may appear overly optimistic when the negative class dominates.

=== Calibration Curves
<calibration-curves>
Calibration focuses on probability quality rather than threshold-based decision quality or ranking quality. Calibration curves can be produced using #NormalTok("CalibrationDisplay"); from #NormalTok("sklearn.calibration");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.calibration ");#ImportTok("import");#NormalTok(" CalibrationDisplay");],
[],
[#NormalTok("CalibrationDisplay.from_predictions(y_test, logit_prob, n_bins");#OperatorTok("=");#DecValTok("10");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Calibration Curve\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'Calibration Curve')");],));
#block[
#box(image("contents\\0/decisioneval_files/figure-typst/cell-17-output-2.svg"))

]
This is a packaged function provided by #NormalTok("sklearn");. If we want to plot multiple curves together in one plot, we can put the axis in the argument of this function.

#Skylighting(([#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots()");],
[],
[#NormalTok("CalibrationDisplay.from_predictions(");],
[#NormalTok("    y_test, logit_prob, n_bins");#OperatorTok("=");#DecValTok("10");#NormalTok(", name");#OperatorTok("=");#StringTok("\"Logistic regression\"");#NormalTok(", ax");#OperatorTok("=");#NormalTok("ax");],
[#NormalTok(")");],
[],
[#NormalTok("CalibrationDisplay.from_predictions(");],
[#NormalTok("    y_test, rf_prob, n_bins");#OperatorTok("=");#DecValTok("10");#NormalTok(", name");#OperatorTok("=");#StringTok("\"Random forest\"");#NormalTok(", ax");#OperatorTok("=");#NormalTok("ax");],
[#NormalTok(")");],));
#box(image("contents\\0/decisioneval_files/figure-typst/cell-18-output-1.svg"))

The calibration curve compares predicted probabilities with observed frequencies.

Calibration curves diagnose probability quality; they do not by themselves recalibrate the model. Recalibration methods such as Platt scaling or isotonic regression can change the probability scale, but they do not necessarily improve AUC because AUC mainly depends on ranking.

#part[Parametric Supervised Learning]
= Linear Regression
<linear-regression>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
This section offers a brief review of linear regression, with the main emphasis on its Python implementation through examples.

== Quick Overview
<quick-overview>
Linear regression is the fundamental supervised learning method for a quantitative response. It models the conditional mean of the response as a linear function of the predictors: $ y = beta_0 + beta_1 x_1 + dots.h.c + beta_p x_p + epsilon . $

In matrix notation, this can be written as \$\$
\\vb y = \\vb X\\beta + \\varepsilon.
\$\$ Here, \$\\vb X\$ is the design matrix, whose first column is a column of ones representing the intercept.

== The Ordinary Least Squares Estimator
<the-ordinary-least-squares-estimator>
The most common fitting method is ordinary least squares (OLS). It chooses the coefficient vector $beta$ that minimizes the residual sum of squares (\$\\rss\$):

\$\$
\\rss(\\beta) = \\sum\_{i=1}^n (y\_i - \\hat{y}\_i)^2
= \\norm{\\vb y - \\vb X\\beta }\_2^2.
\$\$

#theorem(title: [OLS Estimator])[
The coefficient vector that minimizes \$\\rss\$ is \$\$
\\hat{\\beta}\_{\\ols} = (\\vb X^\\top \\vb X)^{-1}\\vb X^\\top \\vb y,
\$\$ provided that \$\\vb X^\\top \\vb X\$ is invertible. This estimator is called the ordinary least squares (OLS) estimator.

] <thm->
Once the coefficients are estimated, the fitted value for observation $i$ is

$ hat(y)_i = hat(beta)_0 + hat(beta)_1 x_(i 1) + dots.h.c + hat(beta)_p x_(i p) . $

Interpretability is one of the main advantages of linear regression compared with many more complex models.

+ The coefficient $beta_j$ describes how the predicted response changes when $x_j$ increases by one unit, while the other predictors are held fixed.
+ When interaction terms are present, a main effect cannot be interpreted in isolation. The effect of a predictor depends on the values of the variables with which it interacts.
+ If predictors are centered so that $0$ corresponds to the average of the original variable, the intercept represents the predicted response at the average predictor levels.

#block[
#callout(
body: 
[
Classical regression primarily focuses on inference and model assumptions, such as normality, constant variance, and independence of errors.

As discussed earlier in the statistical learning basics section, statistical learning places greater emphasis on predictive performance and generalization to unseen data. As a result, estimated test error and model validation often play a more central role than formal inference procedures.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Linear Regression in Python
<linear-regression-in-python>
There are many Python libraries for fitting linear regression models. In this course, we use #link("https://scikit-learn.org/")[#NormalTok("scikit-learn");] as the primary modeling tool, with support from #NormalTok("pandas"); and #NormalTok("numpy"); for data manipulation, and #NormalTok("matplotlib"); and #NormalTok("seaborn"); for visualization.

To demonstrate the code, we generate a dataset with 2 predictors and 1 response variable, where $beta_0 = 1$, $beta_1 = 2$, and $beta_2 = 3$.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("np.random.seed(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[],
[#NormalTok("x1 ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("1");#NormalTok(", ");#FloatTok("0.1");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("x2 ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" x1 ");#OperatorTok("+");#NormalTok(" ");#DecValTok("3");#NormalTok(" ");#OperatorTok("*");#NormalTok(" x2 ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("'x1'");#NormalTok(": x1, ");#StringTok("'x2'");#NormalTok(": x2})");],));
]
When using #NormalTok("sklearn");, a dataset is typically represented by features #NormalTok("X"); and a target variable #NormalTok("y");.

- #NormalTok("X"); usually has 2 dimensions (number of samples × features).
- #NormalTok("y"); is usually 1-dimensional, though it may also be represented as a 2-dimensional array with a single column.

Both #NormalTok("X"); and #NormalTok("y"); can be stored as either #NormalTok("numpy"); arrays or #NormalTok("pandas"); objects.

In this example we construct #NormalTok("X"); as a DataFrame, since column names make it easier to modify variables during the model-building stage, e.g.~when adding interactions or transformations.

=== Linear regression models
<linear-regression-models>
We fit a linear regression model using #NormalTok("LinearRegression");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[],
[#NormalTok("model ");#OperatorTok("=");#NormalTok(" LinearRegression()");],
[#NormalTok("model.fit(X, y)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"intercept: ");#SpecialCharTok("{");#NormalTok("model");#SpecialCharTok(".");#NormalTok("intercept_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"coefficients: ");#SpecialCharTok("{");#NormalTok("model");#SpecialCharTok(".");#NormalTok("coef_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("intercept: 1.2995891152586192");],
[#NormalTok("coefficients: [1.69051379 3.10918568]");],));
]
]
We can then use the fitted model to generate predictions and compute residuals.

#block[
#Skylighting(([#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" model.predict(X)");],
[#NormalTok("res ");#OperatorTok("=");#NormalTok(" y ");#OperatorTok("-");#NormalTok(" y_pred");],));
]
=== Measure model performance
<measure-model-performance>
#NormalTok("sklearn"); provides many performance measures, most of which can be found in #NormalTok("sklearn.metrics");. A common syntax is #NormalTok("metric(y_true, y_pred)");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" mean_squared_error, r2_score, root_mean_squared_error");],
[],
[#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" model.predict(X)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"MSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y, y_pred)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"R2: ");#SpecialCharTok("{");#NormalTok("r2_score(y, y_pred)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"RMSE: ");#SpecialCharTok("{");#NormalTok("root_mean_squared_error(y, y_pred)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
]
Each model also provides a built-in scoring method. For a specific model, you can check the official documentation to see which metric is used, but the general idea is:

- regressors use #NormalTok("r2_score");, and
- classifiers use #NormalTok("accuracy");

#Skylighting(([#NormalTok("model.score(X, y)");],));
#Skylighting(([#NormalTok("0.9723249582312465");],));
Note that $ R^2 = 1 - frac("MSE", "Var" \( y \)) $ #NormalTok("r2_score"); can serve as a normalized negative MSE (up to an additive constant).

=== Model Diagnostics
<model-diagnostics>
In traditional regression, diagnostic plots are powerful tools for detecting potential problems in a fitted model. However, statistical learning primarily focuses on prediction performance rather than model assumptions. Therefore, diagnostics are not our primary focus in this course, and this section is optional.

Click for more details.
In Python there is no single function that automatically produces all diagnostic plots. Instead, we usually combine tools from several libraries. In these notes we focus on basic tools from #NormalTok("statsmodels");, #NormalTok("scipy");, #NormalTok("seaborn");, and #NormalTok("matplotlib");.

We can also use #NormalTok("seaborn");'s theme to improve the appearance of plots produced by #NormalTok("matplotlib");-based tools.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns");],
[#NormalTok("sns.set_theme()");],));
]
We compute several quantities needed for residual analysis. Although our primary modeling tool is #NormalTok("sklearn");, residual diagnostics are easier with #NormalTok("statsmodels");. Therefore we construct a #NormalTok("statsmodels"); model that holds the same data.

Since we already have the feature matrix and the target vector, the fastest way to use #NormalTok("statsmodels"); is through #NormalTok("statsmodels.api"); (as opposed to the R-style interface #NormalTok("statsmodels.formula.api");).

#Skylighting(([#ImportTok("import");#NormalTok(" statsmodels.api ");#ImportTok("as");#NormalTok(" sm");],
[#NormalTok("X_sm ");#OperatorTok("=");#NormalTok(" sm.add_constant(X)");],
[#NormalTok("model ");#OperatorTok("=");#NormalTok(" sm.OLS(y, X_sm).fit()");],
[#NormalTok("model.params");],));
#Skylighting(([#NormalTok("const    1.299589");],
[#NormalTok("x1       1.690514");],
[#NormalTok("x2       3.109186");],
[#NormalTok("dtype: float64");],));
The fitted values, residuals, leverage, Cook's distance, and other quantities can be extracted directly from this #NormalTok("model"); object. We wrap them into DataFrames for easier plotting.

#block[
#Skylighting(([#NormalTok("y_pred ");#OperatorTok("=");#NormalTok(" model.fittedvalues");],
[#NormalTok("res ");#OperatorTok("=");#NormalTok(" model.resid");],
[],
[#NormalTok("model_output ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");],
[#NormalTok("    ");#StringTok("\"y_true\"");#NormalTok(": y,");],
[#NormalTok("    ");#StringTok("\"y_pred\"");#NormalTok(": y_pred,");],
[#NormalTok("    ");#StringTok("\"res\"");#NormalTok(": res");],
[#NormalTok("})");],));
]
#block[
#Skylighting(([#NormalTok("influence ");#OperatorTok("=");#NormalTok(" model.get_influence()");],
[],
[#NormalTok("std_resid ");#OperatorTok("=");#NormalTok(" influence.resid_studentized_internal");],
[#NormalTok("sqrt_std_resid ");#OperatorTok("=");#NormalTok(" np.sqrt(np.");#BuiltInTok("abs");#NormalTok("(std_resid))");],
[#NormalTok("leverage ");#OperatorTok("=");#NormalTok(" influence.hat_matrix_diag");],
[#NormalTok("cooks ");#OperatorTok("=");#NormalTok(" influence.cooks_distance[");#DecValTok("0");#NormalTok("]");],
[],
[#NormalTok("df_diag ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");],
[#NormalTok("    ");#StringTok("\"leverage\"");#NormalTok(": leverage,");],
[#NormalTok("    ");#StringTok("\"std_resid\"");#NormalTok(": std_resid,");],
[#NormalTok("    ");#StringTok("\"sqrt_std_resid\"");#NormalTok(": sqrt_std_resid,");],
[#NormalTok("    ");#StringTok("\"cooks\"");#NormalTok(": cooks");],
[#NormalTok("})");],));
]
#block[
#callout(
body: 
[
The most basic residual plot is simply residuals versus fitted values.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.scatter(y_pred, res)");],
[#NormalTok("plt.axhline(");#DecValTok("0");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(")");],));
#box(image("contents\\1/lr_files/figure-typst/cell-11-output-1.svg"))

If we use #NormalTok("seaborn");, additional features are computed automatically. For example, setting #NormalTok("lowess=True"); will display a smooth trend curve.

#Skylighting(([#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns");],
[],
[#NormalTok("sns.regplot(");],
[#NormalTok("    data");#OperatorTok("=");#NormalTok("model_output,");],
[#NormalTok("    x");#OperatorTok("=");#StringTok("\"y_pred\"");#NormalTok(",");],
[#NormalTok("    y");#OperatorTok("=");#StringTok("\"res\"");#NormalTok(",");],
[#NormalTok("    lowess");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    scatter_kws");#OperatorTok("=");#NormalTok("{");#StringTok("\"alpha\"");#NormalTok(": ");#FloatTok("0.6");#NormalTok("},");],
[#NormalTok("    line_kws");#OperatorTok("=");#NormalTok("{");#StringTok("\"color\"");#NormalTok(": ");#StringTok("\"red\"");#NormalTok(", ");#StringTok("\"linestyle\"");#NormalTok(": ");#StringTok("\"--\"");#NormalTok("},");],
[#NormalTok(")");],
[],
[#NormalTok("plt.axhline(");#DecValTok("0");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(")");],));
#box(image("contents\\1/lr_files/figure-typst/cell-12-output-1.svg"))

]
, 
title: 
[
Residual plots
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#ImportTok("import");#NormalTok(" scipy.stats ");#ImportTok("as");#NormalTok(" stats");],
[],
[#NormalTok("stats.probplot(res, dist");#OperatorTok("=");#StringTok("\"norm\"");#NormalTok(", plot");#OperatorTok("=");#NormalTok("plt)");#OperatorTok(";");],));
#box(image("contents\\1/lr_files/figure-typst/cell-13-output-1.svg"))

]
, 
title: 
[
Q-Q plot
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[],
[#NormalTok("sns.scatterplot(x");#OperatorTok("=");#NormalTok("y_pred, y");#OperatorTok("=");#NormalTok("sqrt_std_resid, data");#OperatorTok("=");#NormalTok("df_diag)");],
[],
[#NormalTok("sns.regplot(");],
[#NormalTok("    x");#OperatorTok("=");#NormalTok("y_pred,");],
[#NormalTok("    y");#OperatorTok("=");#NormalTok("sqrt_std_resid,");],
[#NormalTok("    data");#OperatorTok("=");#NormalTok("df_diag,");],
[#NormalTok("    lowess");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    scatter");#OperatorTok("=");#VariableTok("False");#NormalTok(",");],
[#NormalTok("    line_kws");#OperatorTok("=");#NormalTok("{");#StringTok("\"color\"");#NormalTok(": ");#StringTok("\"red\"");#NormalTok("}");],
[#NormalTok(")");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"Fitted values\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"√|Standardized residuals|\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scale-Location\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\1/lr_files/figure-typst/cell-14-output-1.svg"))

]
, 
title: 
[
Scale-location plot
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#NormalTok("sns.scatterplot(");],
[#NormalTok("    x");#OperatorTok("=");#NormalTok("leverage,");],
[#NormalTok("    y");#OperatorTok("=");#NormalTok("std_resid,");],
[#NormalTok("    data");#OperatorTok("=");#NormalTok("df_diag,");],
[#NormalTok("    size");#OperatorTok("=");#NormalTok("cooks,");],
[#NormalTok("    sizes");#OperatorTok("=");#NormalTok("(");#DecValTok("20");#NormalTok(", ");#DecValTok("200");#NormalTok("),");],
[#NormalTok("    alpha");#OperatorTok("=");#FloatTok("0.7");],
[#NormalTok(")");],
[],
[#NormalTok("plt.axhline(");#DecValTok("0");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"gray\"");#NormalTok(")");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"Leverage\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Standardized Residuals\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Residuals vs Leverage\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\1/lr_files/figure-typst/cell-15-output-1.svg"))

]
, 
title: 
[
Leverage with Cook's distance
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Partial residual plots help visualize the relationship between a predictor and the response after adjusting for the effects of other predictors. #NormalTok("plot_ccpr()"); from #NormalTok("sm.graphics"); can be used to generate partial residual plots.

#Skylighting(([#NormalTok("sm.graphics.plot_ccpr(model, ");#StringTok("\"x1\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\1/lr_files/figure-typst/cell-16-output-1.svg"))

To generate plots for all predictors at once, we can use

#Skylighting(([#NormalTok("sm.graphics.plot_ccpr_grid(model)");#OperatorTok(";");],));
#box(image("contents\\1/lr_files/figure-typst/cell-17-output-1.svg"))

The default #NormalTok("plot_ccpr()"); does not include a smooth curve. If a smooth trend line is desired, we can compute it using the #NormalTok("lowess()"); function and add it manually.

#Skylighting(([#ImportTok("from");#NormalTok(" statsmodels.nonparametric.smoothers_lowess ");#ImportTok("import");#NormalTok(" lowess");],
[],
[#NormalTok("fig ");#OperatorTok("=");#NormalTok(" sm.graphics.plot_ccpr(model, ");#StringTok("\"x1\"");#NormalTok(")");],
[],
[#NormalTok("ax ");#OperatorTok("=");#NormalTok(" fig.axes[");#DecValTok("0");#NormalTok("]");],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" ax.lines[");#DecValTok("0");#NormalTok("].get_xdata()");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ax.lines[");#DecValTok("0");#NormalTok("].get_ydata()");],
[],
[#NormalTok("smooth ");#OperatorTok("=");#NormalTok(" lowess(y, x, frac");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("ax.plot(smooth[:, ");#DecValTok("0");#NormalTok("], smooth[:, ");#DecValTok("1");#NormalTok("], color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(")");],));
#box(image("contents\\1/lr_files/figure-typst/cell-18-output-1.svg"))

The same idea can be applied to the grid version.

#Skylighting(([#NormalTok("fig ");#OperatorTok("=");#NormalTok(" sm.graphics.plot_ccpr_grid(model)");],
[],
[#ControlFlowTok("for");#NormalTok(" ax ");#KeywordTok("in");#NormalTok(" fig.axes:");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(ax.lines) ");#OperatorTok("!=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" ax.lines[");#DecValTok("0");#NormalTok("].get_xdata()");],
[#NormalTok("        y ");#OperatorTok("=");#NormalTok(" ax.lines[");#DecValTok("0");#NormalTok("].get_ydata()");],
[],
[#NormalTok("        smooth ");#OperatorTok("=");#NormalTok(" lowess(y, x, frac");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("        ax.plot(smooth[:, ");#DecValTok("0");#NormalTok("], smooth[:, ");#DecValTok("1");#NormalTok("], color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(")");],));
#box(image("contents\\1/lr_files/figure-typst/cell-19-output-1.svg"))

]
, 
title: 
[
Partial residual plots
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Model evaluation
<model-evaluation>
=== Train-Test Split
<train-test-split>
Instead of estimating test performance indirectly from the training data, we can evaluate a model more directly by using data that were not used to fit the model. This leads to the idea of data splitting:

The dataset is divided into two parts:

- Training set: used to fit the model.
- Test set: used to evaluate prediction performance.

After fitting the model on the training set, predictions are made on the test set, and performance measures such as MSE are computed. This provides a more realistic estimate of how the model performs on new data.

#horizontalrule

In many situations we also need to choose between several competing models or tuning parameters. To avoid using the test data for model selection, a third subset is often introduced.

- Training set: used to fit models.
- Validation set: used to compare models and select tuning parameters.
- Test set: used only once at the end to estimate the final model's performance.

This separation helps prevent overly optimistic performance estimates.

#horizontalrule

In #NormalTok("sklearn");, the function #NormalTok("train_test_split()"); from #NormalTok("sklearn.model_selection"); is commonly used to split the data into a training set and a test set.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("np.random.seed(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[],
[#NormalTok("x1 ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("1");#NormalTok(", ");#FloatTok("0.1");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("x2 ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" x1 ");#OperatorTok("+");#NormalTok(" ");#DecValTok("3");#NormalTok(" ");#OperatorTok("*");#NormalTok(" x2 ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", size");#OperatorTok("=");#NormalTok("n)");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("'x1'");#NormalTok(": x1, ");#StringTok("'x2'");#NormalTok(": x2})");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(X, y, test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],));
]
The argument #NormalTok("test_size=0.2"); means that 20% of the data are used as the test set, while the remaining 80% are used as the training set. The argument #NormalTok("random_state=0"); ensures reproducibility.

=== Cross-Validation
<cross-validation>
When the dataset is not large, splitting the data into separate training, validation, and test sets may leave too little data for model fitting. In such cases, cross-validation is commonly used to estimate validation performance more efficiently.

The most common form is $k$-fold cross-validation.

+ The available training data are divided into $k$ roughly equal parts (called folds).
+ For each fold:
  - The model is trained on $k - 1$ folds.
  - The remaining fold is used as a validation set.
+ This process is repeated $k$ times so that each fold serves once as the validation set.
+ The validation errors from all folds are averaged to estimate the model's expected test error.

#horizontalrule

Cross-validation is primarily used to estimate test error or to compare competing models. When it is used for model selection, two additional steps are typically performed. Note that cross-validation uses only the training data and does not involve the test set.

#block[
#set enum(numbering: "1.", start: 5)
+ After the best model configuration has been selected, the model is retrained on the entire training data.
+ The final model is then evaluated once on the test set, providing an unbiased estimate of its performance on new data.
]

#horizontalrule

In #NormalTok("sklearn");, there are several ways to perform $k$-fold cross-validation. From #NormalTok("KFold"); to #NormalTok("cross_validate"); and then #NormalTok("cross_val_score");, the interface becomes easier to use, but also less flexible.

The three approaches perform essentially the same task, but at different levels of abstraction.

#block[
#callout(
body: 
[
#NormalTok("KFold"); from #NormalTok("sklearn.model_selection"); is used to split the dataset into $k$ groups, called folds. In each iteration, one fold is used as the validation set and the remaining folds are used as the training set.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" KFold");],
[],
[#NormalTok("kf ");#OperatorTok("=");#NormalTok(" KFold(n_splits");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[],
[#ControlFlowTok("for");#NormalTok(" train_idx, val_idx ");#KeywordTok("in");#NormalTok(" kf.split(");#BuiltInTok("range");#NormalTok("(");#DecValTok("10");#NormalTok(")):");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(train_idx, val_idx)");],));
#block[
#Skylighting(([#NormalTok("[2 3 4 5 6 7 8 9] [0 1]");],
[#NormalTok("[0 1 4 5 6 7 8 9] [2 3]");],
[#NormalTok("[0 1 2 3 6 7 8 9] [4 5]");],
[#NormalTok("[0 1 2 3 4 5 8 9] [6 7]");],
[#NormalTok("[0 1 2 3 4 5 6 7] [8 9]");],));
]
]
- Here I use #NormalTok("range(10)"); inside #NormalTok("kf.split()"); because only the indices are needed. If a dataset is passed instead, the output is still the indices for the training set and validation set.
- If you want the split to be randomized, set #NormalTok("shuffle=True"); when creating #NormalTok("KFold");. In that case, you may also specify #NormalTok("random_state"); to make the result reproducible.

Let us now apply #NormalTok("KFold"); to our simulated dataset.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" KFold");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" r2_score");],
[],
[#NormalTok("kf ");#OperatorTok("=");#NormalTok(" KFold(n_splits");#OperatorTok("=");#DecValTok("5");#NormalTok(", shuffle");#OperatorTok("=");#VariableTok("True");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("cv_scores ");#OperatorTok("=");#NormalTok(" []");],
[#ControlFlowTok("for");#NormalTok(" train_idx, val_idx ");#KeywordTok("in");#NormalTok(" kf.split(X):");],
[#NormalTok("    X_train, X_val ");#OperatorTok("=");#NormalTok(" X.iloc[train_idx], X.iloc[val_idx]");],
[#NormalTok("    y_train, y_val ");#OperatorTok("=");#NormalTok(" y[train_idx], y[val_idx]");],
[],
[#NormalTok("    model ");#OperatorTok("=");#NormalTok(" LinearRegression()");],
[#NormalTok("    model.fit(X_train, y_train)");],
[],
[#NormalTok("    y_pred ");#OperatorTok("=");#NormalTok(" model.predict(X_val)");],
[#NormalTok("    mse ");#OperatorTok("=");#NormalTok(" r2_score(y_val, y_pred)");],
[],
[#NormalTok("    cv_scores.append(mse)");],
[],
[#BuiltInTok("print");#NormalTok("(cv_scores)");],
[#BuiltInTok("print");#NormalTok("(");#BuiltInTok("sum");#NormalTok("(cv_scores) ");#OperatorTok("/");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(cv_scores))");],));
#block[
#Skylighting(([#NormalTok("[0.8608451912679863, 0.9481576783569399, 0.9506537898257763, 0.7900723938704974, 0.9219490589471597]");],
[#NormalTok("0.8943356224536719");],));
]
]
This gives the validation MSE for each fold, together with their average.

]
, 
title: 
[
#NormalTok("KFold");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Using #NormalTok("KFold"); directly is somewhat manual. We may use #NormalTok("cross_validate()"); to automate the cross-validation process. Depending on the arguments supplied, #NormalTok("cross_validate()"); may internally use #NormalTok("KFold");.

You may specify which scoreing methods useing #NormalTok("scoring=[]"); argument. The default choice will be the default choice from the model. In #NormalTok("LinearRegression"); case, the default one is #NormalTok("r2_score");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" cross_validate");],
[],
[#NormalTok("model ");#OperatorTok("=");#NormalTok(" LinearRegression()");],
[#NormalTok("cv_result ");#OperatorTok("=");#NormalTok(" cross_validate(model, X, y, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[],
[#NormalTok("cv_result");],));
#Skylighting(([#NormalTok("{'fit_time': array([0.00109625, 0.00072932, 0.00069761, 0.00118828, 0.00086689]),");],
[#NormalTok(" 'score_time': array([0.00055146, 0.00050545, 0.00048828, 0.00056601, 0.00054455]),");],
[#NormalTok(" 'test_score': array([ 0.93895964, -2.04436011,  0.96632851,  0.85985022,  0.91886942])}");],));
If you are only interested in the validation scores, you may extract them directly.

#Skylighting(([#NormalTok("cv_result[");#StringTok("'test_score'");#NormalTok("]");],));
#Skylighting(([#NormalTok("array([ 0.93895964, -2.04436011,  0.96632851,  0.85985022,  0.91886942])");],));
- You may choose different scoring methods. More info can be found in #link("https://scikit-learn.org/stable/modules/model_evaluation.html#scoring-parameter")[the document].
- Here the MSE values are negative because #NormalTok("sklearn"); follows the convention that larger scores are better.
- If #NormalTok("cv=5");, then #NormalTok("KFold(5, shuffle=False)"); is used by default. If you want randomized folds, you may pass a #NormalTok("KFold"); object explicitly.

#Skylighting(([#NormalTok("cv_result ");#OperatorTok("=");#NormalTok(" cross_validate(");],
[#NormalTok("    model, X, y, cv");#OperatorTok("=");#NormalTok("KFold(");#DecValTok("5");#NormalTok(", shuffle");#OperatorTok("=");#VariableTok("True");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok(")");],
[],
[#NormalTok("cv_result[");#StringTok("\"test_score\"");#NormalTok("]");],));
#Skylighting(([#NormalTok("array([0.86084519, 0.94815768, 0.95065379, 0.79007239, 0.92194906])");],));
You may compare these scores with the ones obtained in the #NormalTok("KFold"); section. Usually, the overall cross-validation score is taken to be the mean of the fold scores.

#Skylighting(([#NormalTok("cv_result[");#StringTok("'test_score'");#NormalTok("].mean()");],));
#Skylighting(([#NormalTok("np.float64(0.8943356224536719)");],));
]
, 
title: 
[
#NormalTok("cross_validate");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#NormalTok("cross_val_score()"); is a shorter way to obtain #NormalTok("cv_result[\"test_score\"]"); from the #NormalTok("cross_validate()"); section. The arguments #NormalTok("cv"); and #NormalTok("scoring"); work in the same way.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" cross_val_score");],
[],
[#NormalTok("cv_scores ");#OperatorTok("=");#NormalTok(" cross_val_score(");],
[#NormalTok("    model, X, y, cv");#OperatorTok("=");#NormalTok("KFold(");#DecValTok("5");#NormalTok(", shuffle");#OperatorTok("=");#VariableTok("True");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok(")");],
[],
[#NormalTok("cv_scores");],));
#Skylighting(([#NormalTok("array([0.86084519, 0.94815768, 0.95065379, 0.79007239, 0.92194906])");],));
#Skylighting(([#NormalTok("cv_scores.mean()");],));
#Skylighting(([#NormalTok("np.float64(0.8943356224536719)");],));
So #NormalTok("cross_val_score()"); is convenient when you only need the validation scores and do not need the extra information returned by #NormalTok("cross_validate()");.

]
, 
title: 
[
#NormalTok("cross_val_score");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]

#horizontalrule

Cross-validation is often used to compare competing models. One important application is hyperparameter tuning. In this setting, we compare models from the same family under different choices of hyperparameters. In #NormalTok("sklearn");, this process is commonly carried out with #NormalTok("GridSearchCV");.

The CV procedure is summarized (again) as follows:

+ Split the training data into several folds.
+ For each hyperparameter combination, hold out one fold as the validation set and use the remaining folds as the training set.
+ Fit the model on the training folds and evaluate its performance on the validation fold.
+ Repeat this process so that each fold serves once as the validation set. The average validation score is the cross-validation score for that hyperparameter combination.
+ Repeat Steps 2--4 for all hyperparameter combinations, and select the combination with the best average cross-validation score.
+ #strong[Final step:] After the best hyperparameter combination is identified, the model is refit on the entire training set using these hyperparameters.

#horizontalrule

#NormalTok("GridSearchCV"); automates this process. To illustrate the idea, suppose we want to decide whether a linear regression model should be fit with or without an intercept.

First, specify the hyperparameters to be tuned:

#block[
#Skylighting(([#NormalTok("params ");#OperatorTok("=");#NormalTok(" {");#StringTok("\"fit_intercept\"");#NormalTok(": [");#VariableTok("True");#NormalTok(", ");#VariableTok("False");#NormalTok("]}");],));
]
#block[
#callout(
body: 
[
If the model is wrapped inside a #NormalTok("Pipeline"); or a #NormalTok("ColumnTransformer"); (discussed later), hyperparameters inside a step must be referred to using the syntax #NormalTok("step__param"); with two underscores.

For example, suppose a pipeline contains a step named #NormalTok("linear");, and that step has a hyperparameter called #NormalTok("fit_intercept");. Then the parameter grid should be written as

#block[
#Skylighting(([#NormalTok("params ");#OperatorTok("=");#NormalTok(" {");#StringTok("\"linear__fit_intercept\"");#NormalTok(": [");#VariableTok("True");#NormalTok(", ");#VariableTok("False");#NormalTok("]}");],));
]
]
, 
title: 
[
#NormalTok("Pipeline"); and #NormalTok("ColumnTransformer");
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
Next, construct the grid search.

- The argument #NormalTok("cv"); is specified in the same way as in ordinary #NormalTok("cross-validation");.
- The argument #NormalTok("refit=True"); controls whether the model is refit on the entire training set using the best hyperparameters. The default value is #NormalTok("True");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[],
[#NormalTok("gs ");#OperatorTok("=");#NormalTok(" GridSearchCV(model, param_grid");#OperatorTok("=");#NormalTok("params, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", refit");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("gs.fit(X, y)");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=estimator,-estimator%20object")[estimator #text(fill: rgb("#000"))[estimator: estimator object \
   \
  This is assumed to implement the scikit-learn estimator interface. \
  Either estimator needs to provide a \`\`score\`\` function, \
  or \`\`scoring\`\` must be passed.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); LinearRegression()],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=param_grid,-dict%20or%20list%20of%20dictionaries")[param\_grid #text(fill: rgb("#000"))[param\_grid: dict or list of dictionaries \
   \
  Dictionary with parameters names (\`str\`) as keys and lists of \
  parameter settings to try as values, or a list of such \
  dictionaries, in which case the grids spanned by each dictionary \
  in the list are explored. This enables searching over any sequence \
  of parameter settings.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); {\'fit\_intercept\': \[True, False\]}],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=scoring,-str%2C%20callable%2C%20list%2C%20tuple%20or%20dict%2C%20default%3DNone")[scoring #text(fill: rgb("#000"))[scoring: str, callable, list, tuple or dict, default=None \
   \
  Strategy to evaluate the performance of the cross-validated model on \
  the test set. \
   \
  If \`scoring\` represents a single score, one can use: \
   \
  \- a single string (see :ref:\`scoring\_string\_names\`); \
  \- a callable (see :ref:\`scoring\_callable\`) that returns a single value; \
  \- \`None\`, the \`estimator\`\'s \
  :ref:\`default evaluation criterion \` is used. \
   \
  If \`scoring\` represents multiple scores, one can use: \
   \
  \- a list or tuple of unique strings; \
  \- a callable returning a dictionary where the keys are the metric \
  names and the values are the metric scores; \
  \- a dictionary with metric names as keys and callables as values. \
   \
  See :ref:\`multimetric\_grid\_search\` for an example.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=n_jobs,-int%2C%20default%3DNone")[n\_jobs #text(fill: rgb("#000"))[n\_jobs: int, default=None \
   \
  Number of jobs to run in parallel. \
  \`\`None\`\` means 1 unless in a :obj:\`joblib.parallel\_backend\` context. \
  \`\`-1\`\` means using all processors. See :term:\`Glossary \` \
  for more details. \
   \
  .. versionchanged:: v0.20 \
  \`n\_jobs\` default changed from 1 to None]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=refit,-bool%2C%20str%2C%20or%20callable%2C%20default%3DTrue")[refit #text(fill: rgb("#000"))[refit: bool, str, or callable, default=True \
   \
  Refit an estimator using the best found parameters on the whole \
  dataset. \
   \
  For multiple metric evaluation, this needs to be a \`str\` denoting the \
  scorer that would be used to find the best parameters for refitting \
  the estimator at the end. \
   \
  Where there are considerations other than maximum score in \
  choosing a best estimator, \`\`refit\`\` can be set to a function which \
  returns the selected \`\`best\_index\_\`\` given \`\`cv\_results\_\`\`. In that \
  case, the \`\`best\_estimator\_\`\` and \`\`best\_params\_\`\` will be set \
  according to the returned \`\`best\_index\_\`\` while the \`\`best\_score\_\`\` \
  attribute will not be available. \
   \
  The refitted estimator is made available at the \`\`best\_estimator\_\`\` \
  attribute and permits using \`\`predict\`\` directly on this \
  \`\`GridSearchCV\`\` instance. \
   \
  Also for multiple metric evaluation, the attributes \`\`best\_index\_\`\`, \
  \`\`best\_score\_\`\` and \`\`best\_params\_\`\` will only be available if \
  \`\`refit\`\` is set and all of them will be determined w.r.t this specific \
  scorer. \
   \
  See \`\`scoring\`\` parameter to know more about multiple metric \
  evaluation. \
   \
  See :ref:\`sphx\_glr\_auto\_examples\_model\_selection\_plot\_grid\_search\_digits.py\` \
  to see how to design a custom selection strategy using a callable \
  via \`refit\`. \
   \
  See :ref:\`this example \
  \` \
  for an example of how to use \`\`refit=callable\`\` to balance model \
  complexity and cross-validated score. \
   \
  .. versionchanged:: 0.20 \
  Support for callable added.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=cv,-int%2C%20cross-validation%20generator%20or%20an%20iterable%2C%20default%3DNone")[cv #text(fill: rgb("#000"))[cv: int, cross-validation generator or an iterable, default=None \
   \
  Determines the cross-validation splitting strategy. \
  Possible inputs for cv are: \
   \
  \- None, to use the default 5-fold cross validation, \
  \- integer, to specify the number of folds in a \`(Stratified)KFold\`, \
  \- :term:\`CV splitter\`, \
  \- An iterable yielding (train, test) splits as arrays of indices. \
   \
  For integer/None inputs, if the estimator is a classifier and \`\`y\`\` is \
  either binary or multiclass, :class:\`StratifiedKFold\` is used. In all \
  other cases, :class:\`KFold\` is used. These splitters are instantiated \
  with \`shuffle=False\` so the splits will be the same across calls. \
   \
  Refer :ref:\`User Guide \` for the various \
  cross-validation strategies that can be used here. \
   \
  .. versionchanged:: 0.22 \
  \`\`cv\`\` default value if None changed from 3-fold to 5-fold.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 5],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=verbose,-int")[verbose #text(fill: rgb("#000"))[verbose: int \
   \
  Controls the verbosity: the higher, the more messages. \
   \
  \- \>1 : the computation time for each fold and parameter candidate is \
  displayed; \
  \- \>2 : the score is also displayed; \
  \- \>3 : the fold and candidate parameter indexes are also displayed \
  together with the starting time of the computation.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=pre_dispatch,-int%2C%20or%20str%2C%20default%3D%272%2An_jobs%27")[pre\_dispatch #text(fill: rgb("#000"))[pre\_dispatch: int, or str, default=\'2\*n\_jobs\' \
   \
  Controls the number of jobs that get dispatched during parallel \
  execution. Reducing this number can be useful to avoid an \
  explosion of memory consumption when more jobs get dispatched \
  than CPUs can process. This parameter can be: \
   \
  \- None, in which case all the jobs are immediately created and spawned. Use \
  this for lightweight and fast-running jobs, to avoid delays due to on-demand \
  spawning of the jobs \
  \- An int, giving the exact number of total jobs that are spawned \
  \- A str, giving an expression as a function of n\_jobs, as in \'2\*n\_jobs\']]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'2\*n\_jobs\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=error_score,-%27raise%27%20or%20numeric%2C%20default%3Dnp.nan")[error\_score #text(fill: rgb("#000"))[error\_score: \'raise\' or numeric, default=np.nan \
   \
  Value to assign to the score if an error occurs in estimator fitting. \
  If set to \'raise\', the error is raised. If a numeric value is given, \
  FitFailedWarning is raised. This parameter does not affect the refit \
  step, which will always raise the error.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); nan],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.model_selection.GridSearchCV.html#:~:text=return_train_score,-bool%2C%20default%3DFalse")[return\_train\_score #text(fill: rgb("#000"))[return\_train\_score: bool, default=False \
   \
  If \`\`False\`\`, the \`\`cv\_results\_\`\` attribute will not include training \
  scores. \
  Computing training scores is used to get insights on how different \
  parameter settings impact the overfitting/underfitting trade-off. \
  However computing the scores on the training set can be computationally \
  expensive and is not strictly required to select the parameters that \
  yield the best generalization performance. \
   \
  .. versionadded:: 0.19 \
   \
  .. versionchanged:: 0.21 \
  Default value was changed from \`\`True\`\` to \`\`False\`\`]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
)
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=fit_intercept,-bool%2C%20default%3DTrue")[fit\_intercept #text(fill: rgb("#000"))[fit\_intercept: bool, default=True \
   \
  Whether to calculate the intercept for this model. If set \
  to False, no intercept will be used in calculations \
  (i.e. data is expected to be centered).]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=copy_X,-bool%2C%20default%3DTrue")[copy\_X #text(fill: rgb("#000"))[copy\_X: bool, default=True \
   \
  If True, X will be copied; else, it may be overwritten.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=tol,-float%2C%20default%3D1e-6")[tol #text(fill: rgb("#000"))[tol: float, default=1e-6 \
   \
  The precision of the solution (\`coef\_\`) is determined by \`tol\` which \
  specifies a different convergence criterion for the \`lsqr\` solver. \
  \`tol\` is set as \`atol\` and \`btol\` of :func:\`scipy.sparse.linalg.lsqr\` when \
  fitting on sparse training data. This parameter has no effect when fitting \
  on dense data. \
   \
  .. versionadded:: 1.7]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 1e-06],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=n_jobs,-int%2C%20default%3DNone")[n\_jobs #text(fill: rgb("#000"))[n\_jobs: int, default=None \
   \
  The number of jobs to use for the computation. This will only provide \
  speedup in case of sufficiently large problems, that is if firstly \
  \`n\_targets \> 1\` and secondly \`X\` is sparse or if \`positive\` is set \
  to \`True\`. \`\`None\`\` means 1 unless in a \
  :obj:\`joblib.parallel\_backend\` context. \`\`-1\`\` means using all \
  processors. See :term:\`Glossary \` for more details.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=positive,-bool%2C%20default%3DFalse")[positive #text(fill: rgb("#000"))[positive: bool, default=False \
   \
  When set to \`\`True\`\`, forces the coefficients to be positive. This \
  option is only supported for dense arrays. \
   \
  For a comparison between a linear regression model with positive constraints \
  on the regression coefficients and a linear regression without such constraints, \
  see :ref:\`sphx\_glr\_auto\_examples\_linear\_model\_plot\_nnls.py\`. \
   \
  .. versionadded:: 0.24]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
)
After fitting, the best estimator and other information about the search can be obtained.

#Skylighting(([#NormalTok("gs.best_estimator_");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=fit_intercept,-bool%2C%20default%3DTrue")[fit\_intercept #text(fill: rgb("#000"))[fit\_intercept: bool, default=True \
   \
  Whether to calculate the intercept for this model. If set \
  to False, no intercept will be used in calculations \
  (i.e. data is expected to be centered).]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=copy_X,-bool%2C%20default%3DTrue")[copy\_X #text(fill: rgb("#000"))[copy\_X: bool, default=True \
   \
  If True, X will be copied; else, it may be overwritten.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=tol,-float%2C%20default%3D1e-6")[tol #text(fill: rgb("#000"))[tol: float, default=1e-6 \
   \
  The precision of the solution (\`coef\_\`) is determined by \`tol\` which \
  specifies a different convergence criterion for the \`lsqr\` solver. \
  \`tol\` is set as \`atol\` and \`btol\` of :func:\`scipy.sparse.linalg.lsqr\` when \
  fitting on sparse training data. This parameter has no effect when fitting \
  on dense data. \
   \
  .. versionadded:: 1.7]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 1e-06],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=n_jobs,-int%2C%20default%3DNone")[n\_jobs #text(fill: rgb("#000"))[n\_jobs: int, default=None \
   \
  The number of jobs to use for the computation. This will only provide \
  speedup in case of sufficiently large problems, that is if firstly \
  \`n\_targets \> 1\` and secondly \`X\` is sparse or if \`positive\` is set \
  to \`True\`. \`\`None\`\` means 1 unless in a \
  :obj:\`joblib.parallel\_backend\` context. \`\`-1\`\` means using all \
  processors. See :term:\`Glossary \` for more details.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LinearRegression.html#:~:text=positive,-bool%2C%20default%3DFalse")[positive #text(fill: rgb("#000"))[positive: bool, default=False \
   \
  When set to \`\`True\`\`, forces the coefficients to be positive. This \
  option is only supported for dense arrays. \
   \
  For a comparison between a linear regression model with positive constraints \
  on the regression coefficients and a linear regression without such constraints, \
  see :ref:\`sphx\_glr\_auto\_examples\_linear\_model\_plot\_nnls.py\`. \
   \
  .. versionadded:: 0.24]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
)
#Skylighting(([#NormalTok("gs.best_params_");],));
#Skylighting(([#NormalTok("{'fit_intercept': True}");],));
#Skylighting(([#NormalTok("gs.best_score_");],));
#Skylighting(([#NormalTok("np.float64(0.327929534836043)");],));
#NormalTok("gs.cv_results_"); stores the results for all folds. Itself is a #NormalTok("dict");. Usually we convert it into a DataFrame.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("df_result ");#OperatorTok("=");#NormalTok(" pd.DataFrame(gs.cv_results_)");],
[#NormalTok("df_result");],));
#table(
  columns: 15,
  align: (auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[mean\_fit\_time], table.cell(align: right)[std\_fit\_time], table.cell(align: right)[mean\_score\_time], table.cell(align: right)[std\_score\_time], table.cell(align: right)[param\_fit\_intercept], table.cell(align: right)[params], table.cell(align: right)[split0\_test\_score], table.cell(align: right)[split1\_test\_score], table.cell(align: right)[split2\_test\_score], table.cell(align: right)[split3\_test\_score], table.cell(align: right)[split4\_test\_score], table.cell(align: right)[mean\_test\_score], table.cell(align: right)[std\_test\_score], table.cell(align: right)[rank\_test\_score],),
  table.hline(),
  table.cell(align: horizon)[0], [0.000946], [0.000409], [0.000565], [0.000137], [True], [{\'fit\_intercept\': True}], [0.938960], [-2.044360], [0.966329], [0.859850], [0.918869], [0.327930], [1.186661], [1],
  table.cell(align: horizon)[1], [0.000858], [0.000381], [0.000583], [0.000128], [False], [{\'fit\_intercept\': False}], [0.953318], [-2.278946], [0.979793], [0.854933], [0.900845], [0.281988], [1.281191], [2],
)
Then we could get access to the mean test score or other metrics to see how scores are changed along the parameters.

#Skylighting(([#NormalTok("df_result[");#StringTok("\"mean_test_score\"");#NormalTok("]");],));
#Skylighting(([#NormalTok("0    0.327930");],
[#NormalTok("1    0.281988");],
[#NormalTok("Name: mean_test_score, dtype: float64");],));
#block[
#callout(
body: 
[
You may assign #NormalTok("n_jobs"); for parallel computing. You may leave it #NormalTok("None"); right now. We will come back to it later when we really need it.

]
, 
title: 
[
#NormalTok("n_jobs");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Modern Hyperparameter Tuning
<modern-hyperparameter-tuning>
Historically, one of the most common approaches to hyperparameter tuning was exhaustive grid search, which is introduced above. This approach is conceptually simple and works well when the number of hyperparameters is small. As a result, #NormalTok("GridSearchCV"); became one of the standard tools in early machine learning workflows.

However, as models became more complicated, researchers observed that exhaustive grid search often wastes substantial computation. In many problems, only a few hyperparameters strongly affect performance, while others have relatively small influence.

A particularly influential paper #cite(<Bergstra2012>, form: "prose") by Bergstra and Bengio showed that random search can often outperform grid search in high-dimensional hyperparameter spaces. The main idea is that random search explores more distinct values along important hyperparameter directions instead of spending excessive computation on unimportant dimensions.

This led to the widespread use of methods such as:

- #NormalTok("RandomizedSearchCV");
- Bayesian optimization
- TPE (Tree-structured Parzen Estimator)
- Optuna
- AutoML frameworks

Modern frameworks such as #NormalTok("Optuna"); use adaptive search strategies. Instead of testing hyperparameters independently, they use information from previous trials to guide future searches toward more promising regions of the hyperparameter space. These methods have become increasingly important for large and computationally expensive models.

Nevertheless, in this course we will mainly use ordinary grid search because it is simple, transparent, and easy to understand. For most models in this course, naive grid search is already sufficient.

Only for more computationally expensive models such as XGBoost will we occasionally use more practical workflows such as:

- random search followed by refined grid search
- stagewise tuning
- early stopping

== Feature Engineering and Preprocessing
<feature-engineering-and-preprocessing>
Feature engineering refers to modifying or creating predictors in order to better represent the relationship between the predictors and the response. Here we mainly cover the #NormalTok("sklearn"); way to perform feature engineering.

#block[
#callout(
body: 
[
In statistical learning (commonly implemented using #NormalTok("sklearn");), the primary goal is predictive performance. Models are therefore typically constructed by building a feature matrix, and modifying a model usually means modifying the feature matrix rather than changing a model formula.

In contrast, traditional regression analysis (commonly implemented using #NormalTok("statsmodels");) allows explicit specification of statistical models through a formula language. This approach is convenient when precise control of model terms and statistical inference are required.

]
, 
title: 
[
Modeling Perspective
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Creating Features Manually
<creating-features-manually>
Before introducing automated tools, we can always create new predictors directly by modifying the original dataset.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("'x1'");#NormalTok(": [");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("4");#NormalTok("], ");#StringTok("'x2'");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok("]})");],
[#NormalTok("X");],));
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x1], table.cell(align: right)[x2],),
  table.hline(),
  table.cell(align: horizon)[0], [0], [1],
  table.cell(align: horizon)[1], [2], [3],
  table.cell(align: horizon)[2], [4], [5],
)
For example, we can add the squared term of $x_2$ and the interaction term $x_1 x_2$ to form a new feature matrix #NormalTok("X2");.

#Skylighting(([#NormalTok("X2 ");#OperatorTok("=");#NormalTok(" X.copy()");],
[#NormalTok("X2[");#StringTok("\"x2_sq\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" X[");#StringTok("\"x2\"");#NormalTok("] ");#OperatorTok("**");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("X2[");#StringTok("\"x1_x2\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" X[");#StringTok("\"x1\"");#NormalTok("] ");#OperatorTok("*");#NormalTok(" X[");#StringTok("\"x2\"");#NormalTok("]");],
[#NormalTok("X2");],));
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x1], table.cell(align: right)[x2], table.cell(align: right)[x2\_sq], table.cell(align: right)[x1\_x2],),
  table.hline(),
  table.cell(align: horizon)[0], [0], [1], [1], [0],
  table.cell(align: horizon)[1], [2], [3], [9], [6],
  table.cell(align: horizon)[2], [4], [5], [25], [20],
)
This corresponds to fitting a model of the form $ y = beta_0 + beta_1 x_1 + beta_2 x_2 + beta_3 x_2^2 + beta_4 x_1 x_2 + epsilon . $

#block[
#callout(
body: 
[
Although the model is called linear regression, it can represent nonlinear relationships by including transformed predictors such as $x^2$, $log x$, or $sqrt(x)$. The model remains linear because it is linear in the coefficients $beta$.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Polynomial Features
<polynomial-features>
Click to expand.
When many predictors are present, manually creating polynomial and interaction terms can become tedious. In such cases we can use #NormalTok("PolynomialFeatures"); from #NormalTok("sklearn.preprocessing");, which automatically generates polynomial and interaction terms up to the specified degree.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" PolynomialFeatures");],
[],
[#NormalTok("poly ");#OperatorTok("=");#NormalTok(" PolynomialFeatures(degree");#OperatorTok("=");#DecValTok("2");#NormalTok(", interaction_only");#OperatorTok("=");#VariableTok("False");#NormalTok(", include_bias");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("poly.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[ 1.,  0.,  1.,  0.,  0.,  1.],");],
[#NormalTok("       [ 1.,  2.,  3.,  4.,  6.,  9.],");],
[#NormalTok("       [ 1.,  4.,  5., 16., 20., 25.]])");],));
The argument #NormalTok("interaction_only=False"); means that both squared terms and interaction terms are included. For example, if the original variables are $x_1$ and $x_2$, then the transformed matrix contains terms such as $ 1 \, x_1 \, x_2 \, x_1^2 \, x_1 x_2 \, x_2^2 . $

#Skylighting(([#NormalTok("poly2 ");#OperatorTok("=");#NormalTok(" PolynomialFeatures(degree");#OperatorTok("=");#DecValTok("2");#NormalTok(", interaction_only");#OperatorTok("=");#VariableTok("True");#NormalTok(", include_bias");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok("poly2.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[ 0.,  1.,  0.],");],
[#NormalTok("       [ 2.,  3.,  6.],");],
[#NormalTok("       [ 4.,  5., 20.]])");],));
Here #NormalTok("interaction_only=True"); means that only interaction terms are added, while powers such as $x_1^2$ and $x_2^2$ are excluded. In addition, the argument #NormalTok("include_bias=False"); removes the constant column of ones.
=== Categorical Variables
<categorical-variables>
#block[
#callout(
body: 
[
Including all dummy variables together with an intercept creates perfect multicollinearity because the dummy variables sum to one. Therefore, when creating dummy variables with $k$ categories, we typically include only $k - 1$ variables.

]
, 
title: 
[
Dummy Variable Trap
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
#NormalTok("pandas"); version
We could use #NormalTok("pd.get_dummies()"); to directly modify the dataset.

#Skylighting(([#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"color\"");#NormalTok(": [");#StringTok("\"red\"");#NormalTok(", ");#StringTok("\"blue\"");#NormalTok(", ");#StringTok("\"green\"");#NormalTok(", ");#StringTok("\"red\"");#NormalTok("]})");],
[],
[#NormalTok("pd.get_dummies(df, drop_first");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[color\_green], table.cell(align: right)[color\_red],),
  table.hline(),
  table.cell(align: horizon)[0], [False], [True],
  table.cell(align: horizon)[1], [False], [False],
  table.cell(align: horizon)[2], [True], [False],
  table.cell(align: horizon)[3], [False], [True],
)
The argument #NormalTok("drop_first=True"); removes the base category column to avoid the dummy variable trap described above. If you want to keep the base column, you may set it to #NormalTok("False"); (which is the default).

#NormalTok("pd.get_dummies()"); automatically detects categorical variables and leaves numerical variables unchanged.

#Skylighting(([#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"x\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("6");#NormalTok("], ");#StringTok("\"group\"");#NormalTok(": [");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok("]})");],
[],
[#NormalTok("pd.get_dummies(X, drop_first");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x], table.cell(align: right)[group\_B], table.cell(align: right)[group\_C],),
  table.hline(),
  table.cell(align: horizon)[0], [1], [False], [False],
  table.cell(align: horizon)[1], [2], [False], [False],
  table.cell(align: horizon)[2], [3], [True], [False],
  table.cell(align: horizon)[3], [4], [True], [False],
  table.cell(align: horizon)[4], [5], [False], [True],
  table.cell(align: horizon)[5], [6], [False], [True],
)
If you want to convert numeric variables into dummy variables, you may manually cast them to categorical variables.

#Skylighting(([#NormalTok("X[");#StringTok("\"x\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" X[");#StringTok("\"x\"");#NormalTok("].astype(");#StringTok("\"category\"");#NormalTok(")");],
[#NormalTok("pd.get_dummies(X, drop_first");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
#table(
  columns: 8,
  align: (auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x\_2], table.cell(align: right)[x\_3], table.cell(align: right)[x\_4], table.cell(align: right)[x\_5], table.cell(align: right)[x\_6], table.cell(align: right)[group\_B], table.cell(align: right)[group\_C],),
  table.hline(),
  table.cell(align: horizon)[0], [False], [False], [False], [False], [False], [False], [False],
  table.cell(align: horizon)[1], [True], [False], [False], [False], [False], [False], [False],
  table.cell(align: horizon)[2], [False], [True], [False], [False], [False], [True], [False],
  table.cell(align: horizon)[3], [False], [False], [True], [False], [False], [True], [False],
  table.cell(align: horizon)[4], [False], [False], [False], [True], [False], [False], [True],
  table.cell(align: horizon)[5], [False], [False], [False], [False], [True], [False], [True],
)
#NormalTok("sklearn"); version
#NormalTok("OneHotEncoder"); from #NormalTok("sklearn"); is another tool for converting categorical variables into dummy variables. It follows the standard #NormalTok("sklearn"); API. Compared with #NormalTok("pd.get_dummies()");, which is convenient for quick data analysis, #NormalTok("OneHotEncoder"); is better suited for statistical learning pipelines because it can be fitted on training data and then applied consistently to new data.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" OneHotEncoder");],
[],
[#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"color\"");#NormalTok(": [");#StringTok("\"red\"");#NormalTok(", ");#StringTok("\"blue\"");#NormalTok(", ");#StringTok("\"green\"");#NormalTok(", ");#StringTok("\"red\"");#NormalTok("]})");],
[#NormalTok("encoder ");#OperatorTok("=");#NormalTok(" OneHotEncoder(drop");#OperatorTok("=");#StringTok("\"first\"");#NormalTok(", sparse_output");#OperatorTok("=");#VariableTok("False");#NormalTok(") ");],
[],
[#NormalTok("encoder.fit_transform(df)");],));
#Skylighting(([#NormalTok("array([[0., 1.],");],
[#NormalTok("       [0., 0.],");],
[#NormalTok("       [1., 0.],");],
[#NormalTok("       [0., 1.]])");],));
The argument #NormalTok("sparse_output=False"); controls the output format. If #NormalTok("False");, the output is a regular matrix. If #NormalTok("True");, the output is a sparse matrix.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" OneHotEncoder");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"x\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("6");#NormalTok("], ");#StringTok("\"group\"");#NormalTok(": [");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok("]})");],
[#NormalTok("encoder ");#OperatorTok("=");#NormalTok(" OneHotEncoder(drop");#OperatorTok("=");#StringTok("\"first\"");#NormalTok(", sparse_output");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[],
[#NormalTok("encoder.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[0., 0., 0., 0., 0., 0., 0.],");],
[#NormalTok("       [1., 0., 0., 0., 0., 0., 0.],");],
[#NormalTok("       [0., 1., 0., 0., 0., 1., 0.],");],
[#NormalTok("       [0., 0., 1., 0., 0., 1., 0.],");],
[#NormalTok("       [0., 0., 0., 1., 0., 0., 1.],");],
[#NormalTok("       [0., 0., 0., 0., 1., 0., 1.]])");],));
When applied to a DataFrame with multiple columns, unlike the #NormalTok("pandas"); version, #NormalTok("OneHotEncoder"); converts each column into dummy variables. In the example above, the first five columns correspond to #NormalTok("x"); and the last two correspond to #NormalTok("group");.

If you want to apply #NormalTok("OneHotEncoder"); only to certain columns, you need to use a #NormalTok("ColumnTransformer");, which will be introduced later.

=== Scaling Variables
<sec-scaling>
Centralization, standardization and normalization
In regression and statistical learning, these transformations are typically applied to the predictors $X$ to control their location and scale. They are rarely applied to the response $y$, unless there is a specific modeling reason.

- Centralization: Subtract the sample mean so that the variable has mean $0$.
- Standardization: Subtract the sample mean and divide by the sample standard deviation so that the variable has mean $0$ and standard deviation $1$.
- Normalization: Rescale the variable so that its values lie between $0$ and $1$.

Standardization is especially useful when predictors are measured on very different scales. It is commonly used in statistical learning, particularly for methods such as ridge regression and lasso.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("np.random.seed(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"x1\"");#NormalTok(": np.random.normal(");#DecValTok("10");#NormalTok(", ");#DecValTok("2");#NormalTok(", size");#OperatorTok("=");#DecValTok("8");#NormalTok("), ");#StringTok("\"x2\"");#NormalTok(": np.random.normal(");#DecValTok("100");#NormalTok(", ");#DecValTok("20");#NormalTok(", size");#OperatorTok("=");#DecValTok("8");#NormalTok(")})");],
[#NormalTok("X");],));
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x1], table.cell(align: right)[x2],),
  table.hline(),
  table.cell(align: horizon)[0], [13.248691], [106.380782],
  table.cell(align: horizon)[1], [8.776487], [95.012592],
  table.cell(align: horizon)[2], [8.943656], [129.242159],
  table.cell(align: horizon)[3], [7.854063], [58.797186],
  table.cell(align: horizon)[4], [11.730815], [93.551656],
  table.cell(align: horizon)[5], [5.396923], [92.318913],
  table.cell(align: horizon)[6], [13.489624], [122.675389],
  table.cell(align: horizon)[7], [8.477586], [78.002175],
)
Standardization:

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[],
[#NormalTok("scaler ");#OperatorTok("=");#NormalTok(" StandardScaler()");],
[#NormalTok("scaler.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[ 1.32733855,  0.43959384],");],
[#NormalTok("       [-0.36436724, -0.09299622],");],
[#NormalTok("       [-0.3011319 ,  1.51063   ],");],
[#NormalTok("       [-0.71329383, -1.78965739],");],
[#NormalTok("       [ 0.75316998, -0.16143987],");],
[#NormalTok("       [-1.64275917, -0.21919283],");],
[#NormalTok("       [ 1.41847649,  1.20298239],");],
[#NormalTok("       [-0.47743287, -0.88991991]])");],));
Centralization (standardization without scaling):

#Skylighting(([#NormalTok("scaler ");#OperatorTok("=");#NormalTok(" StandardScaler(with_std");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok("scaler.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[  3.50896013,   9.38317551],");],
[#NormalTok("       [ -0.96324342,  -1.98501392],");],
[#NormalTok("       [ -0.7960741 ,  32.24455233],");],
[#NormalTok("       [ -1.88566784, -38.2004206 ],");],
[#NormalTok("       [  1.99108467,  -3.44595049],");],
[#NormalTok("       [ -4.34280799,  -4.6786935 ],");],
[#NormalTok("       [  3.74989294,  25.67778244],");],
[#NormalTok("       [ -1.26214439, -18.99543176]])");],));
Normalization:

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" MinMaxScaler");],
[],
[#NormalTok("minmax ");#OperatorTok("=");#NormalTok(" MinMaxScaler()");],
[#NormalTok("minmax.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[0.97022838, 0.67547185],");],
[#NormalTok("       [0.41760651, 0.51409498],");],
[#NormalTok("       [0.43826331, 1.        ],");],
[#NormalTok("       [0.30362424, 0.        ],");],
[#NormalTok("       [0.78266733, 0.49335628],");],
[#NormalTok("       [0.        , 0.47585691],");],
[#NormalTok("       [1.        , 0.90678157],");],
[#NormalTok("       [0.38067187, 0.27262398]])");],));
Note that scaling is not required for ordinary least squares (OLS). However, it is essential for regularization methods such as ridge and lasso because the penalty depends on the scale of the coefficients.
=== #NormalTok("ColumnTransformer");
<columntransformer>
Click to expand.
To apply different transformations to different columns, we can use #NormalTok("ColumnTransformer");. #NormalTok("ColumnTransformer"); consists of multiple transformations. Each transformation is specified by a triple containing:

- a name (identifier),
- the transformer,
- the columns to which it applies.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.compose ");#ImportTok("import");#NormalTok(" ColumnTransformer");],
[],
[#NormalTok("prep ");#OperatorTok("=");#NormalTok(" ColumnTransformer(");],
[#NormalTok("    transformers");#OperatorTok("=");#NormalTok("[");],
[#NormalTok("        (");#StringTok("\"cat\"");#NormalTok(", OneHotEncoder(drop");#OperatorTok("=");#StringTok("\"first\"");#NormalTok(", sparse_output");#OperatorTok("=");#VariableTok("False");#NormalTok("), [");#StringTok("\"group\"");#NormalTok("]),");],
[#NormalTok("        (");#StringTok("\"x\"");#NormalTok(", ");#StringTok("\"passthrough\"");#NormalTok(", [");#StringTok("\"x\"");#NormalTok("]),");],
[#NormalTok("        (");#StringTok("\"x_std\"");#NormalTok(", StandardScaler(), [");#StringTok("\"x\"");#NormalTok("]),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");#StringTok("\"x\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("6");#NormalTok("], ");#StringTok("\"group\"");#NormalTok(": [");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok("]})");],
[#NormalTok("prep.fit_transform(X)");],));
#Skylighting(([#NormalTok("array([[ 0.        ,  0.        ,  1.        , -1.46385011],");],
[#NormalTok("       [ 0.        ,  0.        ,  2.        , -0.87831007],");],
[#NormalTok("       [ 1.        ,  0.        ,  3.        , -0.29277002],");],
[#NormalTok("       [ 1.        ,  0.        ,  4.        ,  0.29277002],");],
[#NormalTok("       [ 0.        ,  1.        ,  5.        ,  0.87831007],");],
[#NormalTok("       [ 0.        ,  1.        ,  6.        ,  1.46385011]])");],));
You may use the id to get into each transformer.

#Skylighting(([#NormalTok("prep.transformers_");],));
#Skylighting(([#NormalTok("[('cat', OneHotEncoder(drop='first', sparse_output=False), ['group']),");],
[#NormalTok(" ('x',");],
[#NormalTok("  FunctionTransformer(accept_sparse=True, check_inverse=False,");],
[#NormalTok("                      feature_names_out='one-to-one'),");],
[#NormalTok("  ['x']),");],
[#NormalTok(" ('x_std', StandardScaler(), ['x'])]");],));
#Skylighting(([#NormalTok("prep.named_transformers_[");#StringTok("'x_std'");#NormalTok("]");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=copy,-bool%2C%20default%3DTrue")[copy #text(fill: rgb("#000"))[copy: bool, default=True \
   \
  If False, try to avoid a copy and do inplace scaling instead. \
  This is not guaranteed to always work inplace; e.g. if the data is \
  not a NumPy array or scipy.sparse CSR matrix, a copy may still be \
  returned.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_mean,-bool%2C%20default%3DTrue")[with\_mean #text(fill: rgb("#000"))[with\_mean: bool, default=True \
   \
  If True, center the data before scaling. \
  This does not work (and will raise an exception) when attempted on \
  sparse matrices, because centering them entails building a dense \
  matrix which in common use cases is likely to be too large to fit in \
  memory.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_std,-bool%2C%20default%3DTrue")[with\_std #text(fill: rgb("#000"))[with\_std: bool, default=True \
   \
  If True, scale the data to unit variance (or equivalently, \
  unit standard deviation).]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
)
#block[
#callout(
body: 
[
In #NormalTok("sklearn");, all models are called estimators. An estimator is any object that can be trained using the #NormalTok(".fit()"); method.

Once an estimator is fitted,

- if it can transform input data using #NormalTok(".transform()");, it is called a transformer;
- if it can generate predictions using #NormalTok(".predict()");, it is called a predictor.

Typical examples include

- Transformers: #NormalTok("StandardScaler");, #NormalTok("MinMaxScaler");, #NormalTok("PolynomialFeatures");, #NormalTok("OneHotEncoder");, etc.
- Predictors: #NormalTok("LinearRegression"); and most other machine learning models.

Usually a model is applied in two steps:

+ #NormalTok(".fit()"); learns the parameters from the training data.
+ #NormalTok(".transform()"); or #NormalTok(".predict()"); applies the model to data.

For transformers, the combined method #NormalTok(".fit_transform()"); performs both steps in one call.

]
, 
title: 
[
Estimator, Predictor and Transformer
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
== Pipelines and transformations of $y$
<pipelines-and-transformations-of-y>
In many modeling workflows, several steps must be performed before fitting the model. These steps may include

- feature transformations,
- scaling variables,
- generating polynomial features.

A #NormalTok("pipeline"); combines these steps into a single object. Using pipelines ensures that the same transformations are applied consistently during training, cross-validation, and prediction, and helps prevent data leakage.

Here is a typical #NormalTok("pipeline");. Each step is indicated by a pair consisting of

- a name (identifier) of the step
- the estimator

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[],
[#NormalTok("steps ");#OperatorTok("=");#NormalTok(" [");],
[#NormalTok("    (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("    (");#StringTok("\"linear_model\"");#NormalTok(", LinearRegression()),");],
[#NormalTok("]");],
[#NormalTok("pipe ");#OperatorTok("=");#NormalTok(" Pipeline(steps");#OperatorTok("=");#NormalTok("steps)");],));
]
This #NormalTok("pipe"); object behaves like a #NormalTok("model"); object. You may use the step names to access the internal components.

#Skylighting(([#NormalTok("pipe.steps");],));
#Skylighting(([#NormalTok("[('scaler', StandardScaler()), ('linear_model', LinearRegression())]");],));
#Skylighting(([#NormalTok("pipe.named_steps[");#StringTok("'scaler'");#NormalTok("]");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=copy,-bool%2C%20default%3DTrue")[copy #text(fill: rgb("#000"))[copy: bool, default=True \
   \
  If False, try to avoid a copy and do inplace scaling instead. \
  This is not guaranteed to always work inplace; e.g. if the data is \
  not a NumPy array or scipy.sparse CSR matrix, a copy may still be \
  returned.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_mean,-bool%2C%20default%3DTrue")[with\_mean #text(fill: rgb("#000"))[with\_mean: bool, default=True \
   \
  If True, center the data before scaling. \
  This does not work (and will raise an exception) when attempted on \
  sparse matrices, because centering them entails building a dense \
  matrix which in common use cases is likely to be too large to fit in \
  memory.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_std,-bool%2C%20default%3DTrue")[with\_std #text(fill: rgb("#000"))[with\_std: bool, default=True \
   \
  If True, scale the data to unit variance (or equivalently, \
  unit standard deviation).]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
)
In a pipeline, you normally need to manually name all components. To make this easier, you may use #NormalTok("make_pipeline()");, which automatically generates default names for each step.

In addition, #NormalTok("make_pipeline()"); does not require a #NormalTok("list"); of #NormalTok("(name, step)"); pairs. Instead, you simply provide the steps one by one.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" make_pipeline");],
[],
[#NormalTok("pipe_easy ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LinearRegression()");],
[#NormalTok(")");],));
]
It will automatically name each step by its class name.

#Skylighting(([#NormalTok("pipe_easy.named_steps");],));
#Skylighting(([#NormalTok("{'standardscaler': StandardScaler(), 'linearregression': LinearRegression()}");],));
#block[
#callout(
body: 
[
Pipelines are particularly useful when combined with cross-validation and hyperparameter tuning, since they ensure that preprocessing steps are applied within each training fold.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== #NormalTok("TransformedTargetRegressor");
<transformedtargetregressor>
#NormalTok("TransformedTargetRegressor"); from #NormalTok("sklearn.compose"); is a wrapper that applies a transformation to the response variable $y$ during model fitting and automatically applies the inverse transformation when making predictions. In other words, the regressor is trained on the transformed response, while predictions are converted back to the original scale.

Here is a simple example of a #NormalTok("TransformedTargetRegressor");. The transformation of $y$ is centralizer, which is essentially standardizer without rescaling.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.compose ");#ImportTok("import");#NormalTok(" TransformedTargetRegressor");],
[],
[#NormalTok("model ");#OperatorTok("=");#NormalTok(" TransformedTargetRegressor(");],
[#NormalTok("    regressor");#OperatorTok("=");#NormalTok("LinearRegression(),");],
[#NormalTok("    transformer");#OperatorTok("=");#NormalTok("StandardScaler(with_std");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok(")");],));
]
=== Full Example
<full-example>
Click to expand.
In this example we build a more complicated pipeline.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("np.random.seed(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" pd.DataFrame(");],
[#NormalTok("    {");],
[#NormalTok("        ");#StringTok("\"x1\"");#NormalTok(": np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", n),");],
[#NormalTok("        ");#StringTok("\"x2\"");#NormalTok(": np.random.normal(");#DecValTok("5");#NormalTok(", ");#DecValTok("2");#NormalTok(", n),");],
[#NormalTok("        ");#StringTok("\"group\"");#NormalTok(": np.random.choice([");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok("], size");#OperatorTok("=");#NormalTok("n),");],
[#NormalTok("    }");],
[#NormalTok(")");],
[],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" X[");#StringTok("\"x1\"");#NormalTok("] ");#OperatorTok("-");#NormalTok(" ");#FloatTok("1.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" X[");#StringTok("\"x2\"");#NormalTok("] ");#OperatorTok("+");#NormalTok(" ");#DecValTok("3");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[");#StringTok("\"group\"");#NormalTok("] ");#OperatorTok("==");#NormalTok(" ");#StringTok("\"B\"");#NormalTok(") ");#OperatorTok("-");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[");#StringTok("\"group\"");#NormalTok("] ");#OperatorTok("==");#NormalTok(" ");#StringTok("\"C\"");#NormalTok(") ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", n)");],));
]
The pipeline is illustrated as follows.

+ #NormalTok("ColumnTransformer"); separates numeric and categorical features.
+ Numeric features go through: #NormalTok("StandardScaler"); → #NormalTok("PolynomialFeatures");.
+ Categorical features go through #NormalTok("OneHotEncoder");.
+ The transformed features are combined into a single feature matrix.
+ The model #NormalTok("LinearRegression"); is fitted to the transformed data.
+ The response variable $y$ is centralized.
+ The fitted model can then be used to generate predictions, while the transforamtion of $y$ is automatically reversed.

#block[

#block[
#box(image("contents\\1/lr_files\\figure-typst\\mermaid-figure-1.png", height: 9.55in, width: 9.76in))

]

]
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.compose ");#ImportTok("import");#NormalTok(" ColumnTransformer, TransformedTargetRegressor");],
[#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler, OneHotEncoder, PolynomialFeatures");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[],
[],
[#NormalTok("numeric_features ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"x1\"");#NormalTok(", ");#StringTok("\"x2\"");#NormalTok("]");],
[#NormalTok("categorical_features ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"group\"");#NormalTok("]");],
[],
[#NormalTok("numeric_pipe ");#OperatorTok("=");#NormalTok(" Pipeline([(");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()), (");#StringTok("\"poly\"");#NormalTok(", PolynomialFeatures(degree");#OperatorTok("=");#DecValTok("2");#NormalTok(", include_bias");#OperatorTok("=");#VariableTok("False");#NormalTok("))])");],
[],
[#NormalTok("preprocessor ");#OperatorTok("=");#NormalTok(" ColumnTransformer(");],
[#NormalTok("    [(");#StringTok("\"num\"");#NormalTok(", numeric_pipe, numeric_features), (");#StringTok("\"cat\"");#NormalTok(", OneHotEncoder(drop");#OperatorTok("=");#StringTok("\"first\"");#NormalTok("), categorical_features)]");],
[#NormalTok(")");],
[],
[#NormalTok("pipe ");#OperatorTok("=");#NormalTok(" Pipeline([(");#StringTok("\"preprocess\"");#NormalTok(", preprocessor), (");#StringTok("\"model\"");#NormalTok(", LinearRegression())])");],
[#NormalTok("model ");#OperatorTok("=");#NormalTok(" TransformedTargetRegressor(regressor");#OperatorTok("=");#NormalTok("pipe, transformer");#OperatorTok("=");#NormalTok("StandardScaler(with_std");#OperatorTok("=");#VariableTok("False");#NormalTok("))");],));
]
The entire #NormalTok("pipeline"); is trained on the training set and then evaluated on the validation set, where the training and validation sets are determined by cross-validation.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" cross_validate");],
[],
[#NormalTok("cv_result ");#OperatorTok("=");#NormalTok(" cross_validate(");],
[#NormalTok("    model, X, y, cv");#OperatorTok("=");#NormalTok("KFold(");#DecValTok("5");#NormalTok(", shuffle");#OperatorTok("=");#VariableTok("True");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("), scoring");#OperatorTok("=");#NormalTok("[");#StringTok("\"r2\"");#NormalTok(", ");#StringTok("\"neg_mean_squared_error\"");#NormalTok("]");],
[#NormalTok(")");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"test R2: ");#SpecialCharTok("{");#NormalTok("cv_result[");#StringTok("'test_r2'");#NormalTok("]");#SpecialCharTok(".");#NormalTok("mean()");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"test neg mse: ");#SpecialCharTok("{");#NormalTok("cv_result[");#StringTok("'test_neg_mean_squared_error'");#NormalTok("]");#SpecialCharTok(".");#NormalTok("mean()");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("test R2: 0.9092762998061948");],
[#NormalTok("test neg mse: -1.0197334955585524");],));
]
]
= Regularization
<regularization>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
== Motivation
<motivation>
The OLS estimator is attractive because, under the Gauss--Markov assumptions, it is BLUE: the best linear unbiased estimator. However, when some predictors are nearly collinear, the matrix $X^top X$ becomes nearly singular. In that case, the variance of \$\\hat\\beta\_{\\ols}\$ can be very large, so the estimated coefficients may become unstable and unreliable.

This leads to the bias-variance trade-off. By allowing a small amount of bias, we may substantially reduce the variance and improve predictive performance. A common way to do this is through regularization.

Two of the most important regularization methods are ridge regression and lasso. Both methods tend to shrink the coefficients toward zero, so they are also called shrinkage methods.

== Ridge Regression
<ridge-regression>
=== OLS esimator review
<ols-esimator-review>
Consider a linear model $ y = X beta + epsilon . $

Given the dataset $X$ and $y$, the OLS estimator \$\\hat\\beta\_{\\ols}\$ finds the coefficient vector $beta$ that minimizes the residual sum of squares \$\$
\\rss(\\beta)=\\norm{y-X\\beta}\_2^2.
\$\$ In other words, \$\$
\\hat{\\beta}\_{\\ols} = \\arg\\min\_{\\beta}\\qty{\\norm{y - X\\beta}\_2^2}.
\$\$ When $X^top X$ is invertible, the solution is \$\$
\\hat{\\beta}\_{\\ols} = (X^\\top X)^{-1}X^\\top y.
\$\$

=== Ridge estimator
<ridge-estimator>
Ridge regression modifies the OLS loss function by adding a quadratic penalty.

#definition(title: [Ridge Regression])[
For a response vector $y in bb(R)^n$ and a design matrix $X in bb(R)^(n times p)$, the Ridge estimator \$\\hat{\\beta}\_{\\ridge}\$ is defined as: \$\$
\\hat{\\beta}\_{\\ridge} = \\arg\\min\_{\\beta} \\qty{ \\norm{y - X\\beta}\_2^2 + \\lambda \\norm{\\beta}\_2^2 }
\$\$ where

- $lambda gt.eq 0$ is the regularization parameter that controls the trade-off between the fit to the data and the penalty on the coefficient size.
- \$\\norm{\\beta}\_2^2 = \\sum\_{j=1}^p \\beta\_j^2\$ is the $L_2$ norm of the coefficient vector

] <def->
The penalty shrinks the coefficients toward zero. Larger values of $lambda$ produce stronger shrinkage. However, ridge regression does not perform variable selection, since it rarely sets any coefficient exactly to zero.

Similar to the OLS estimator, the Ridge estimator can be solved analytically.

#theorem(title: [The Closed-Form of Ridge estimator])[
The closed-form solution of \$\\hat\\beta\_{\\ridge}\$ is \$\$
\\hat{\\beta}\_{\\ridge} = (X^\\top X + \\lambda I)^{-1} X^\\top y.
\$\$

Click for proof.
Consider the ridge regression objective

\$\$
Q(\\beta)
=
(y-X\\beta)^\\top (y-X\\beta) + \\lambda \\beta^\\top \\beta, \\quad \\text{ where }\$\\lambda \\ge 0\$.
\$\$

We derive the ridge estimator by minimizing $Q \( beta \)$ with respect to $beta$.

First expand the quadratic form:

$ Q \( beta \) & = \( y^top - beta^top X^top \) \( y - X beta \) + lambda beta^top beta\
 & = y^top y - y^top X beta - beta^top X^top y + beta^top X^top X beta + lambda beta^top beta . $

Since $y^top X beta$ is a scalar, it equals its transpose:

$ y^top X beta = beta^top X^top y . $

Thus

$ Q \( beta \) = y^top y - 2 beta^top X^top y + beta^top X^top X beta + lambda beta^top beta . $

Combine the last two quadratic terms:

$ Q \( beta \) = y^top y - 2 beta^top X^top y + beta^top \( X^top X + lambda I \) beta . $

Now differentiate with respect to $beta$:

$ nabla_beta Q \( beta \) = - 2 X^top y + 2 \( X^top X + lambda I \) beta . $

Set the gradient equal to zero:

$ - 2 X^top y + 2 \( X^top X + lambda I \) beta = 0 . $

So

$ \( X^top X + lambda I \) beta = X^top y . $

Assuming $X^top X + lambda I$ is invertible, we obtain

\$\$
\\hat{\\beta}\_{\\ridge}
=
(X^\\top X+\\lambda I)^{-1}X^\\top y .
\$\$

Therefore the ridge estimator is

\$\$
\\hat{\\beta}\_{\\ridge}
=
(X^\\top X+\\lambda I)^{-1}X^\\top y.
\$\$

] <thm->
In this formulation, the term $lambda I$ (where $I$ is the identity matrix) is added to the cross-product matrix $X^top X$ before inversion. This ensures that the matrix is non-singular and well-conditioned, even in the presence of multicollinearity or when $p > n$.

=== About intercept
<about-intercept>
Linear regression models are commonly written in the form

$ y = X beta + epsilon . $

This notation can represent two different model structures depending on whether an intercept is included.

- Model with intercept: $beta = \[ beta_0 \, beta_1 \, dots.h \, beta_p \]^top$ where $beta_0$ is the intercept. The design matrix $X$ contains a leading column of ones representing the constant term.
- Model without intercept: $beta = \[ beta_1 \, dots.h \, beta_p \]^top$ and the design matrix contains only the predictor variables. In this case the fitted regression surface is forced to pass through the origin.

In most practical applications, models with an intercept are preferred because they allow the regression function to shift vertically rather than being constrained to go through the origin.

#block[
#callout(
body: 
[
A model with an intercept can be rewritten as a no-intercept model by centering both the response and the predictors:

$ y^c = y - macron(y) \, #h(2em) X_j^c = X_j - macron(X)_j . $

After centering, all variables have mean zero. In ordinary least squares, the intercept estimate is

$ hat(beta)_0 = macron(y) - sum_(j = 1)^p hat(beta)_j macron(X)_j . $

When the data are centered, this quantity becomes zero automatically. As a result, fitting a regression without an intercept on centered data produces the same fitted model as fitting a regression with an intercept on the original data.

]
, 
title: 
[
Centering and the No-Intercept Form
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
For OLS, the intercept formulation and the centered no-intercept formulation are mathematically equivalent. However, the situation is slightly different in ridge regression. The ridge estimator introduces the penalty $ lambda sum_(j = 1)^p beta_j^2 \, $ which is intended to shrink the slope coefficients. In practice the intercept is not penalized, because penalizing it would shrink the overall level of the model toward zero and make the result depend on the arbitrary origin of the response variable.

For this reason ridge regression is usually formulated in the no-intercept form after centering the data, so that the penalty naturally applies only to the slope coefficients.

#block[
#callout(
body: 
[
Because the ridge penalty depends on the sizes of the coefficients, ridge regression is usually implemented after standardizing the predictors. This puts the predictors on a common scale, so that the penalty treats them fairly.

In practice, the predictors are typically standardized, whereas the response is usually only centered rather than standardized.

For details see #ref(<sec-scaling>, supplement: [Section]).

]
, 
title: 
[
Standardization in Practice
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
In #NormalTok("scikit-learn");, ridge and lasso regression automatically center the data internally when fitting the model (while leaving the final predictions on the original scale). The intercept is therefore handled separately and excluded from the penalty.

Because of this internal preprocessing, users typically do not need to manually center the response when using #NormalTok("Ridge"); or #NormalTok("Lasso");. However, it is still common to standardize the predictors explicitly using tools such as #NormalTok("StandardScaler");, especially when building modeling pipelines.

]
, 
title: 
[
Implementation in #NormalTok("scikit-learn");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Alternative Formulation
<alternative-formulation>
By the theory of Lagrange multipliers, ridge regression can also be written in a constrained optimization form:

\$\$
\\hat{\\beta}\_{\\ridge}
=
\\arg\\min\_{\\beta} \\norm{y-X\\beta}\_2^2
\\quad
\\text{subject to}
\\quad
\\norm{\\beta}\_2^2 \\le s .
\$\$

Here $s gt.eq 0$ controls the size of the coefficient vector and is directly related to the penalty parameter $lambda$. The two parameters have an inverse relationship:

- Large $s$ corresponds to small $lambda$. The constraint is weak, and $beta$ approaches the OLS estimator.
- Small $s$ corresponds to large $lambda$. The constraint is strong, and $beta$ shrinks toward $0$.

This formulation highlights that ridge regression limits the magnitude of the coefficient vector rather than directly penalizing prediction error. We will later use this interpretation to explain the difference between ridge regression and lasso.

#block[
#callout(
body: 
[
Ridge regression can be formulated as a constrained optimization problem, where we minimize RSS subject to a constriant $s$ on the squared $L_2$ norm of the coefficients: \$\$
\\min\_{\\beta} \\norm{y - X\\beta}\_2^2 \\quad \\text{subject to} \\quad \\norm{\\beta}\_2^2 \\le s.
\$\$

To solve this, we define the Lagrangian function $cal(L) \( beta \, lambda \)$: \$\$
\\mathcal{L}(\\beta, \\lambda) = \\norm{y - X\\beta}\_2^2 + \\lambda (\\norm{\\beta}\_2^2 - s)
\$\$ where $lambda gt.eq 0$ is the Lagrange multiplier. Taking the partial derivative with respect to $beta$ and setting it to zero gives: $ frac(partial cal(L), partial beta) = - 2 X^top \( y - X beta \) + 2 lambda beta = 0 $ Rearranging the terms yields the standard ridge estimator: $ \( X^top X + lambda I \) beta = X^top y arrow.r.double.long hat(beta)_(upright("ridge")) = \( X^top X + lambda I \)^(- 1) X^top y . $ This shows that for every $lambda > 0$, there exists an equivalent constrained problem with some constraint $s$.

]
, 
title: 
[
The Constrained Optimization Problem
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
The connection between the penalty parameter $lambda$ and the constraint $s$ can be explained as follows. The Lagrange multiplier method implies that at the optimal solution

$ lambda \( parallel beta parallel_2^2 - s \) = 0 $ This leads to two scenarios:

- Non-binding constraint: If the OLS solution already satisfies \$\\norm{\\hat{\\beta}\_{\\text{ols}}}\_2^2 \< s\$, then $lambda = 0$. The constraint has no effect, and the estimator reduces to the OLS estimator \$\\hat{\\beta}\_{\\ols}\$.
- Binding constraint: If \$\\norm{\\hat{\\beta}\_{\\text{ols}}}\_2^2 \> s\$, the constraint is active. In this case, $lambda > 0$ and the solution must lie exactly on the boundary \$\\norm{\\hat{\\beta}\_{\\text{ridge}}}\_2^2 = s\$.

Therefore, the parameters $lambda$ and $s$ are related through \$\$
\\norm{(X^\\top X + \\lambda I)^{-1}X^\\top y}\_2^2 = s,
\\quad
\\text{when } \\lambda \> 0 .
\$\$

$lambda$ is effectively the "price" paid to satisfy the constraint. As $s$ decreases, $lambda$ must increase (heavier penalty) to pull the estimate further away from the OLS solution and toward the origin. Because the norm of the ridge estimator is a strictly decreasing function of $lambda$, for any \$s \< \\norm{\\hat{\\beta}\_{\\ols}}\_2^2\$, there exists a unique $lambda > 0$ such that \$\\norm{\\hat{\\beta}\_{\\text{ridge}}}\_2^2 = s\$.

]
, 
title: 
[
Relation Between $lambda$ and $s$
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== SVD and Tikhonov Regularization
<svd-and-tikhonov-regularization>
Click to expand.
Recall the OLS estimator

\$\$
\\hat{\\beta}\_{\\ols} = (X^\\top X)^{-1}X^\\top y .
\$\$

Let the singular value decomposition (SVD) of $X$ be

$ X = U D V^top \, $

where

- $U$ is an $n times n$ orthogonal matrix,
- $V$ is a $p times p$ orthogonal matrix,
- $D$ is an $n times p$ diagonal matrix whose nonzero entries $d_1 \, dots.h \, d_r$ are the singular values of $X$.

Using the SVD,

$ X^top X = V D^top D V^top . $

Since $D^top D = upright(d i a g) \( d_1^2 \, dots.h \, d_r^2 \)$, the eigenvalues of $X^top X$ are $d_i^2$. \
Hence the OLS estimator can be written as

\$\$
\\hat{\\beta}\_{\\ols}
=
V(D^\\top D)^{-1}D^\\top U^\\top y .
\$\$

Since $D^top D = upright(d i a g) \( d_1^2 \, dots.h \, d_r^2 \)$, we have

\$\$
(D^\\top D)^{-1}=\\mathrm{diag}\\qty(\\frac{1}{d\_1^2},\\ldots,\\frac{1}{d\_r^2}).
\$\$ Let $u_i$ and $v_i$ denote the columns of $U$ and $V$. Then the estimator can be written as

\$\$
\\hat{\\beta}\_{\\ols}
=
\\sum\_{i=1}^{r}
\\frac{1}{d\_i}\\, v\_i\\, u\_i^\\top y .
\$\$

If some singular values $d_i$ are very small, the factors $1 \/ d_i$ become very large, which leads to unstable coefficient estimates. Therefore this expression reveals the instability of OLS.

Now turn to Ridge regression. We replace the OLS estimator with

$ hat(beta)_(upright("ridge")) = \( X^top X + lambda I \)^(- 1) X^top y . $

Substituting the SVD gives

$ hat(beta)_(upright("ridge")) = V \( D^top D + lambda I \)^(- 1) D^top U^top y . $

Because $D^top D$ is diagonal, the estimator can be written componentwise as

$ hat(beta)_(upright("ridge")) = sum_(i = 1)^r frac(d_i, d_i^2 + lambda) v_i thin u_i^top y . $

This representation shows that ridge regression applies a shrinkage factor

$ frac(d_i^2, d_i^2 + lambda) $

to each principal component direction.

- When $d_i$ is large, the factor is close to $1$, so the component is almost unchanged.
- When $d_i$ is small, the factor becomes small, shrinking the unstable directions.

Thus ridge regression stabilizes the estimator by shrinking the contributions of directions associated with small singular values.

#block[
#callout(
body: 
[
Tikhonov regularization is a method used to solve ill-posed problems and handle multicollinearity by adding a penalty term, \$\\alpha\\norm{L\\beta}\_2^2\$. When the Tikhonov matrix $L$ is the identity matrix $I$, it simplifies to ridge regression. Therefore, ridge regression is a special case of Tikhonov regularization @tikhonov1977solutions@hastie2009elements.

]
, 
title: 
[
Tikhonov regularization
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Bias-Variance Tradeoff
<bias-variance-tradeoff>
One of the main motivations for regularization methods is the bias-variance tradeoff. A more flexible model can fit the training data very well, but it may also be highly sensitive to random noise in the sample. In contrast, a more constrained model is usually more stable, but may systematically miss part of the true signal.

This tradeoff can be described mathematically through a decomposition of the expected prediction error.

Suppose the true model is $ Y = f \( x \) + epsilon \, quad "E" \( epsilon \) = 0 \, quad "Var" \( epsilon \) = sigma^2 . $

Let $hat(f) \( x \)$ be an estimator of $f \( x \)$ constructed from a training sample. Since the training sample is random, $hat(f) \( x \)$ is also random. We study the expected prediction error at a fixed point $x$: \$\$
\\operatorname{E}\\qty\[(Y-\\hat f(x))^2\].
\$\$

Here, the expectation is taken over both the randomness in the training data and the randomness in the new response $Y$.

#definition(title: [Bias and Variance])[
~

- $"Bias" \( hat(f) \( x \) \) = "E" \[ hat(f) \( x \) \] - f \( x \)$.
- \$\\operatorname{Var}(\\hat f(x))=\\operatorname{E}\\qty\[\\qty(\\hat f(x)-\\operatorname{E}\[\\hat f(x)\])^2\]\$.

] <def->
#theorem(title: [Bias-Variance Decomposition])[
\$\$
\\operatorname{E}\\qty\[(Y-\\hat f(x))^2\]
=
\\operatorname{Bias}(\\hat f(x))^2+\\operatorname{Var}(\\hat f(x))+\\sigma^2.
\$\$

Click to expand.
Since $Y = f \( x \) + epsilon$, \$\$
\\begin{split}
\\operatorname{E}\\qty\[(Y-\\hat f(x))^2\]&=\\operatorname{E}\\qty\[(f(x)+\\varepsilon-\\hat f(x))^2\]\\\\
&=\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2+2\\varepsilon(f(x)-\\hat f(x))+\\varepsilon^2\]\\\\
&=\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\]+2\\operatorname{E}\\qty\[\\varepsilon(f(x)-\\hat f(x))\]+\\operatorname{E}(\\varepsilon^2).
\\end{split}
\$\$

Since the new noise $epsilon$ is independent of the training data and has mean $0$, \$\$
\\operatorname{E}\\qty\[\\varepsilon(f(x)-\\hat f(x))\]=0.
\$\$ Also, $ "E" \( epsilon^2 \) = "Var" \( epsilon \) = sigma^2 . $

Therefore, \$\$
\\operatorname{E}\\qty\[(Y-\\hat f(x))^2\]
=
\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\]+\\sigma^2.
\$\$

Thus the prediction error is the sum of:

- the estimation error $bb(E) \[ \( f \( x \) - hat(f) \( x \) \)^2 \]$,
- the irreducible error $sigma^2$.

Now we further decompose \$\$
\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\].
\$\$

Let $ m \( x \) = "E" \[ hat(f) \( x \) \] \, $ where the expectation is taken over the randomness in the training sample. Then \$\$
f(x)-\\hat f(x)=\\qty(f(x)-m(x))+\\qty(m(x)-\\hat f(x)).
\$\$

Squaring, \$\$
(f(x)-\\hat f(x))^2
=
(f(x)-m(x))^2
+
(m(x)-\\hat f(x))^2
+
2\\qty(f(x)-m(x))\\qty(m(x)-\\hat f(x)).
\$\$

Taking expectation, \$\$
\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\]
=
(f(x)-m(x))^2
+
\\operatorname{E}\\qty\[(m(x)-\\hat f(x))^2\]
+
2\\qty(f(x)-m(x))\\operatorname{E}\[m(x)-\\hat f(x)\].
\$\$

But $ "E" \[ m \( x \) - hat(f) \( x \) \] = m \( x \) - "E" \[ hat(f) \( x \) \] = 0 . $

So the cross term vanishes, and we obtain \$\$
\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\]
=
\\qty(f(x)-\\operatorname{E}\[\\hat f(x)\])^2
+
\\operatorname{E}\\qty\[\\qty(\\hat f(x)-\\operatorname{E}\[\\hat f(x)\])^2\].
\$\$

The first term is the squared bias: \$\$
\\operatorname{Bias}(\\hat f(x))^2
=
\\qty(\\operatorname{E}\[\\hat f(x)\]-f(x))^2.
\$\$

The second term is the variance: \$\$
\\operatorname{Var}(\\hat f(x))
=
\\operatorname{E}\\qty\[\\qty(\\hat f(x)-\\operatorname{E}\[\\hat f(x)\])^2\].
\$\$

Therefore, \$\$
\\operatorname{E}\\qty\[(f(x)-\\hat f(x))^2\]
=
\\operatorname{Bias}(\\hat f(x))^2+\\operatorname{Var}(\\hat f(x)).
\$\$

Combining this with the earlier decomposition gives \$\$
\\operatorname{E}\\qty\[(Y-\\hat f(x))^2\]
=
\\operatorname{Bias}(\\hat f(x))^2+\\operatorname{Var}(\\hat f(x))+\\sigma^2.
\$\$
] <thm->
This formula shows that the expected prediction error has three parts:

- Squared bias: error caused by systematic deviation of the estimator from the truth.
- Variance: error caused by sensitivity of the estimator to the particular training sample.
- Irreducible error: the noise level $sigma^2$, which cannot be removed by any method.

A very flexible model often has small bias but large variance. A more constrained model often has larger bias but smaller variance. The goal of regularization is not necessarily to minimize bias or variance alone, but to balance them so that the total prediction error is as small as possible.

#block[
#callout(
body: 
[
Ordinary least squares is often unbiased, but its variance can be very large when predictors are highly correlated or when the model is too flexible. Ridge and lasso (which will be discussed later) introduce bias by shrinking the coefficients toward $0$, but this often substantially reduces variance.

As a result, although ridge or lasso may fit the training data less perfectly than OLS, they can achieve better prediction performance on new data. This is the central idea behind the bias-variance tradeoff and one of the main reasons regularization methods are useful in statistical learning.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Ridge Regression in Python
<ridge-regression-in-python>
We use the following simulated dataset to demonstrate ridge regression.

The covariance matrix has a very high correlation, so the two predictors $x_1$ and $x_2$ are highly correlated.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("2");#NormalTok(")");],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("30");],
[],
[#NormalTok("Sigma ");#OperatorTok("=");#NormalTok(" np.array([[");#DecValTok("1");#NormalTok(", ");#FloatTok("0.99");#NormalTok("], [");#FloatTok("0.99");#NormalTok(", ");#DecValTok("1");#NormalTok("]])");],
[#NormalTok("mean ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("])");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean, Sigma, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("X[:, ");#DecValTok("0");#NormalTok("] ");#OperatorTok("+");#NormalTok(" X[:, ");#DecValTok("1");#NormalTok("], scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
The data set is generated from a model with $"E" \( y divides x_1 \, x_2 \) = x_1 + x_2$. Therefore the true coefficients are $beta_1 = beta_2 = 1$.

=== Ridge estimator
<ridge-estimator-1>
We use #NormalTok("Ridge"); from #NormalTok("sklearn.linear_model"); to fit a ridge regression model. Its API is very similar to that of OLS. The argument #NormalTok("alpha"); is the regularization parameter $lambda$.

For simplicity, we use a no-intercept model, so we set #NormalTok("fit_intercept=False");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Ridge");],
[],
[#NormalTok("ridge ");#OperatorTok("=");#NormalTok(" Ridge(alpha");#OperatorTok("=");#DecValTok("5");#NormalTok(", fit_intercept");#OperatorTok("=");#VariableTok("False");#NormalTok(").fit(X, y)");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Ridge beta = ");#SpecialCharTok("{");#NormalTok("ridge");#SpecialCharTok(".");#NormalTok("coef_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Ridge beta = [0.85769874 0.84964704]");],));
]
]
For comparison, we also fit the OLS estimator.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[],
[#NormalTok("ols ");#OperatorTok("=");#NormalTok(" LinearRegression(fit_intercept");#OperatorTok("=");#VariableTok("False");#NormalTok(").fit(X, y)");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"OLS beta = ");#SpecialCharTok("{");#NormalTok("ols");#SpecialCharTok(".");#NormalTok("coef_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("OLS beta = [0.99640827 0.85969191]");],));
]
]
In this example, you may notice two things:

- The ridge coefficients are smaller in magnitude than the OLS coefficients.
- The OLS coefficients may happen to be closer to the true values in this single sample.

The second point is due to randomness in the simulated data. To see the general pattern, we repeat the simulation many times.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("res ");#OperatorTok("=");#NormalTok(" []");],
[#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("100");#NormalTok("):");],
[#NormalTok("    X ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean, Sigma, size");#OperatorTok("=");#NormalTok("n)");],
[#NormalTok("    y ");#OperatorTok("=");#NormalTok(" rng.normal(loc");#OperatorTok("=");#NormalTok("X[:, ");#DecValTok("0");#NormalTok("] ");#OperatorTok("+");#NormalTok(" X[:, ");#DecValTok("1");#NormalTok("], scale");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ols ");#OperatorTok("=");#NormalTok(" LinearRegression(fit_intercept");#OperatorTok("=");#VariableTok("False");#NormalTok(").fit(X, y)");],
[#NormalTok("    ridge ");#OperatorTok("=");#NormalTok(" Ridge(alpha");#OperatorTok("=");#DecValTok("5");#NormalTok(", fit_intercept");#OperatorTok("=");#VariableTok("False");#NormalTok(").fit(X, y)");],
[#NormalTok("    res.append(");],
[#NormalTok("        {");],
[#NormalTok("            ");#StringTok("\"ols_b1\"");#NormalTok(": ols.coef_[");#DecValTok("0");#NormalTok("],");],
[#NormalTok("            ");#StringTok("\"ols_b2\"");#NormalTok(": ols.coef_[");#DecValTok("1");#NormalTok("],");],
[#NormalTok("            ");#StringTok("\"ridge_b1\"");#NormalTok(": ridge.coef_[");#DecValTok("0");#NormalTok("],");],
[#NormalTok("            ");#StringTok("\"ridge_b2\"");#NormalTok(": ridge.coef_[");#DecValTok("1");#NormalTok("],");],
[#NormalTok("        }");],
[#NormalTok("    )");],
[#NormalTok("res ");#OperatorTok("=");#NormalTok(" pd.DataFrame(res)");],));
]
The first five results are shown below. We can see that the OLS estimates vary substantially from sample to sample.

#Skylighting(([#NormalTok("res.head(");#DecValTok("5");#NormalTok(")");],));
#table(
  columns: 5,
  align: (auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[ols\_b1], table.cell(align: right)[ols\_b2], table.cell(align: right)[ridge\_b1], table.cell(align: right)[ridge\_b2],),
  table.hline(),
  table.cell(align: horizon)[0], [1.642753], [0.343583], [0.908249], [0.883823],
  table.cell(align: horizon)[1], [1.105216], [0.774858], [0.885627], [0.858433],
  table.cell(align: horizon)[2], [-0.978268], [3.091366], [0.797745], [1.092525],
  table.cell(align: horizon)[3], [1.301118], [0.325411], [0.781313], [0.728571],
  table.cell(align: horizon)[4], [-0.626684], [2.741871], [0.926826], [1.008491],
)
This becomes even clearer in the boxplot below, which shows that the ridge estimator has much smaller variance than the OLS estimator.

#Skylighting(([#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns");],
[#NormalTok("sns.boxplot(res)");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-7-output-1.svg"))

=== Contour map
<contour-map>
The variance of both $hat(beta)_1$ and $hat(beta)_2$ is quite large under OLS. This is because the variance of $hat(bold(beta))$ is $sigma^2 \( upright(bold(X))^top upright(bold(X)) \)^(- 1)$. Since the columns of $upright(bold(X))$ are highly correlated, the smallest eigenvalue of $upright(bold(X))^top upright(bold(X))$ is close to zero, making the largest eigenvalue of $\( upright(bold(X))^top upright(bold(X)) \)^(- 1)$ very large.

To see things in more details, we first build the RSS function. For each $beta_1$ and $beta_2$ in the range, we form a model $hat(y)_beta = beta_1 x_1 + beta_2 x_2$ and use it to compute \$\\rss = \\sum (y-\\hat y)^2\$.

#block[
#Skylighting(([#NormalTok("beta1_vals ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("beta2_vals ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("B1, B2 ");#OperatorTok("=");#NormalTok(" np.meshgrid(beta1_vals, beta2_vals)");],
[],
[#NormalTok("betas ");#OperatorTok("=");#NormalTok(" np.column_stack([B1.ravel(), B2.ravel()])");],
[#NormalTok("preds ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("@");#NormalTok(" betas.T");],
[#NormalTok("rss_term ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((y[:, ");#VariableTok("None");#NormalTok("] ");#OperatorTok("-");#NormalTok(" preds) ");#OperatorTok("**");#NormalTok(" ");#DecValTok("2");#NormalTok(", axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[#NormalTok("rss_value0 ");#OperatorTok("=");#NormalTok(" rss_term.reshape(B1.shape)");],));
]
We then construct the contour map for the \$\\rss\$ surface, plotting the isolines that correspond to the 1%, 2.5%, 5%, 20%, 50%, and 75% quantiles of the distribution. The ture coefficient $\( beta_1 = 1 \, beta_2 = 1 \)$ is displayed as the red dot, as well as the estimated $beta$ as a blue square in the countour map.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("quant_levels ");#OperatorTok("=");#NormalTok(" np.quantile(rss_value0, [");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.025");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.75");#NormalTok("])");],
[],
[#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("cs ");#OperatorTok("=");#NormalTok(" ax.contour(B1, B2, rss_value0, levels");#OperatorTok("=");#NormalTok("quant_levels, colors");#OperatorTok("=");#StringTok("\"steelblue\"");#NormalTok(")");],
[#NormalTok("ax.clabel(cs, inline");#OperatorTok("=");#VariableTok("True");#NormalTok(", fontsize");#OperatorTok("=");#DecValTok("8");#NormalTok(", fmt");#OperatorTok("=");#StringTok("\"%.0f\"");#NormalTok(")");],
[],
[#NormalTok("ax.plot(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#StringTok("\"ro\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("10");#NormalTok(", label");#OperatorTok("=");#StringTok("\"True (1, 1)\"");#NormalTok(")");],
[#NormalTok("ax.plot(ols.coef_[");#DecValTok("0");#NormalTok("], ols.coef_[");#DecValTok("1");#NormalTok("], ");#StringTok("\"bs\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("10");#NormalTok(", label");#OperatorTok("=");#StringTok("\"OLS estimate\"");#NormalTok(")");],
[],
[#NormalTok("ax.set_xlabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_1");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[#NormalTok("ax.set_ylabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_2");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[#NormalTok("ax.set_title(");#StringTok("\"OLS Objective Function Contours\"");#NormalTok(")");],
[#NormalTok("ax.legend()");],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-9-output-1.svg"))

The contour map reveals a narrow, elongated valley in the \$\\rss\$ objective function. While the surface is highly sensitive to movement perpendicular to the valley, it remains relatively flat along the valley floor. Because the surface is particularly flat in this longitudinal direction, numerous parameter combinations yield nearly identical \$\\rss\$ values. Consequently, the data provides insufficient information to distinguish between points along this axis, making the \$\\rss\$ minimum highly unstable. This lack of identifiability is the fundamental cause of high variance in the estimated coefficients.

When ridge regression is applied, the \$\\rss\$ objective function is modified by adding a penalty term. As a result, the objective surface no longer exhibits a long, flat valley floor. Instead, the minimum becomes more well-defined, and the estimate is pulled toward the origin. Although the true parameter may no longer lie at the bottom of this modified valley, the ridge estimate has substantially lower variance. In this way, ridge regression stabilizes the estimation by controlling the region along the valley floor where the OLS solution would otherwise vary widely.

Here we show the \$\\rss\$ objective function contours for $lambda = 0.1$, $1$, $10$ and $100$.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Ridge");],
[],
[#NormalTok("beta1_vals ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("beta2_vals ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("B1, B2 ");#OperatorTok("=");#NormalTok(" np.meshgrid(beta1_vals, beta2_vals)");],
[],
[#NormalTok("lambda_vals ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("100");#NormalTok("]");],
[],
[],
[#NormalTok("fig, axes ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("2");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("8");#NormalTok("))");],
[],
[#ControlFlowTok("for");#NormalTok(" ax, reg_lambda ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(axes.ravel(), lambda_vals):");],
[#NormalTok("    betas ");#OperatorTok("=");#NormalTok(" np.column_stack([B1.ravel(), B2.ravel()])");],
[#NormalTok("    preds ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("@");#NormalTok(" betas.T");],
[#NormalTok("    rss_term ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("((y[:, ");#VariableTok("None");#NormalTok("] ");#OperatorTok("-");#NormalTok(" preds) ");#OperatorTok("**");#NormalTok(" ");#DecValTok("2");#NormalTok(", axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[#NormalTok("    penalty_term ");#OperatorTok("=");#NormalTok(" reg_lambda ");#OperatorTok("*");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(betas");#OperatorTok("**");#DecValTok("2");#NormalTok(", axis");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    rss_value ");#OperatorTok("=");#NormalTok(" (rss_term ");#OperatorTok("+");#NormalTok(" penalty_term).reshape(B1.shape)");],
[],
[#NormalTok("    quant_levels ");#OperatorTok("=");#NormalTok(" np.quantile(rss_value, [");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.025");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.75");#NormalTok("])");],
[],
[#NormalTok("    cs ");#OperatorTok("=");#NormalTok(" ax.contour(B1, B2, rss_value, levels");#OperatorTok("=");#NormalTok("quant_levels, colors");#OperatorTok("=");#StringTok("\"steelblue\"");#NormalTok(")");],
[#NormalTok("    ax.clabel(cs, inline");#OperatorTok("=");#VariableTok("True");#NormalTok(", fontsize");#OperatorTok("=");#DecValTok("7");#NormalTok(", fmt");#OperatorTok("=");#StringTok("\"%.0f\"");#NormalTok(")");],
[],
[#NormalTok("    ridge ");#OperatorTok("=");#NormalTok(" Ridge(alpha");#OperatorTok("=");#NormalTok("reg_lambda, fit_intercept");#OperatorTok("=");#VariableTok("False");#NormalTok(").fit(X, y)");],
[],
[#NormalTok("    ax.plot(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#StringTok("\"ro\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("8");#NormalTok(", label");#OperatorTok("=");#StringTok("\"True (1,1)\"");#NormalTok(")");],
[#NormalTok("    ax.plot(ridge.coef_[");#DecValTok("0");#NormalTok("], ridge.coef_[");#DecValTok("1");#NormalTok("], ");#StringTok("\"bs\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("8");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Ridge\"");#NormalTok(")");],
[],
[#NormalTok("    ax.set_title(");#VerbatimStringTok("r\"");#DecValTok("$");#ErrorTok("\\");#VerbatimStringTok("lambda");#DecValTok("$");#VerbatimStringTok(" = {}\"");#NormalTok(".");#BuiltInTok("format");#NormalTok("(reg_lambda))");],
[#NormalTok("    ax.set_xlabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_1");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_2");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("handles, labels ");#OperatorTok("=");#NormalTok(" axes[");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("].get_legend_handles_labels()");],
[#NormalTok("fig.suptitle(");#StringTok("\"Ridge Objective Function Contours for Different lambda Values\"");#NormalTok(")");],
[#NormalTok("fig.legend(handles, labels, loc");#OperatorTok("=");#StringTok("\"right\"");#NormalTok(")");],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-10-output-1.svg"))

As $lambda$ increases, the bottom of the valley gradually becomes more rounded, and the objective surface rises more steeply as the coefficients move away from the origin. This additional curvature removes the long flat valley floor and makes the minimum more clearly defined. At the same time, the penalty pulls the estimated coefficients toward the origin, so the ridge estimate is effectively dragged toward zero.

Geometrically, this shrinkage prevents the estimator from drifting freely along the nearly flat valley direction that appears in the OLS objective. As a result, the ridge estimator is much more stable and typically has substantially lower variance than the OLS estimator, although this improvement comes at the cost of introducing some bias.

#block[
#callout(
body: 
[
The Gram matrix $X top X$ represents the raw inner products of predictors. In the context of \$\\rss\$ map, it is the direct source of the surface geometry.

The Covariance matrix is essentially the Gram matrix of the centered data, usually scaled by $n - 1$. $ upright(bold(S)) = frac(1, n - 1) sum \( x_i - macron(x) \) \( x_i - macron(x) \)^t o p . $

Therefore if the data is already centered, the Gram matrix and the covariance matrix are directly related: $X top X = \( n - 1 \) "Cov"$.

Mathematically, these two directions (the longitudinal axis and the perpendicular axis) correspond to the eigenvectors of the $upright(bold(X))^T upright(bold(X))$ matrix (or, equivalently, the principal components of the predictor space). The flatness or steepness in those directions is governed by their corresponding eigenvalues.

#block[
#Skylighting(([#NormalTok("XTX ");#OperatorTok("=");#NormalTok(" X.T ");#OperatorTok("@");#NormalTok(" X");],
[#NormalTok("eigenvalues, eigenvectors ");#OperatorTok("=");#NormalTok(" np.linalg.eigh(XTX)");],
[#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(eigenvalues)):");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f'eigenvalue: ");#SpecialCharTok("{");#NormalTok("eigenvalues[i]");#SpecialCharTok(": .2f}");#SpecialStringTok(", eigenbasis: ");#SpecialCharTok("{");#NormalTok("eigenvectors[i]");#SpecialCharTok("}");#SpecialStringTok("'");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("eigenvalue:  0.26, eigenbasis: [ 0.70320986 -0.71098234]");],
[#NormalTok("eigenvalue:  95.19, eigenbasis: [-0.71098234 -0.70320986]");],));
]
]
Then mark the eigenvectors in the contour map.

#Skylighting(([#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[],
[#NormalTok("quant_levels ");#OperatorTok("=");#NormalTok(" np.quantile(rss_value0, [");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.025");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.75");#NormalTok("])");],
[#NormalTok("cs ");#OperatorTok("=");#NormalTok(" ax.contour(B1, B2, rss_value0, levels");#OperatorTok("=");#NormalTok("quant_levels, colors");#OperatorTok("=");#StringTok("\"lightblue\"");#NormalTok(")");],
[#NormalTok("ax.clabel(cs, inline");#OperatorTok("=");#VariableTok("True");#NormalTok(", fontsize");#OperatorTok("=");#DecValTok("8");#NormalTok(", fmt");#OperatorTok("=");#StringTok("\"%.0f\"");#NormalTok(")");],
[],
[#NormalTok("ax.plot(");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#StringTok("\"ro\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("10");#NormalTok(", label");#OperatorTok("=");#StringTok("\"True (1, 1)\"");#NormalTok(")");],
[#NormalTok("ax.plot(ols.coef_[");#DecValTok("0");#NormalTok("], ols.coef_[");#DecValTok("1");#NormalTok("], ");#StringTok("\"bs\"");#NormalTok(", markersize");#OperatorTok("=");#DecValTok("10");#NormalTok(", label");#OperatorTok("=");#StringTok("\"OLS estimate\"");#NormalTok(")");],
[],
[#NormalTok("scale ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.6");],
[#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(eigenvalues)):");],
[#NormalTok("    v ");#OperatorTok("=");#NormalTok(" eigenvectors[:, i]");],
[#NormalTok("    ax.arrow(");],
[#NormalTok("        ols.coef_[");#DecValTok("0");#NormalTok("],");],
[#NormalTok("        ols.coef_[");#DecValTok("1");#NormalTok("],");],
[#NormalTok("        v[");#DecValTok("0");#NormalTok("] ");#OperatorTok("*");#NormalTok(" scale,");],
[#NormalTok("        v[");#DecValTok("1");#NormalTok("] ");#OperatorTok("*");#NormalTok(" scale,");],
[#NormalTok("        head_width");#OperatorTok("=");#FloatTok("0.05");#NormalTok(",");],
[#NormalTok("        head_length");#OperatorTok("=");#FloatTok("0.1");#NormalTok(",");],
[#NormalTok("        fc");#OperatorTok("=");#StringTok("\"orange\"");#NormalTok(",");],
[#NormalTok("        ec");#OperatorTok("=");#StringTok("\"orange\"");#NormalTok(",");],
[#NormalTok("        label");#OperatorTok("=");#StringTok("\"Eigenvectors\"");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" i ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#StringTok("\"\"");#NormalTok(",");],
[#NormalTok("    )");],
[],
[#NormalTok("    ax.text(");],
[#NormalTok("        ols.coef_[");#DecValTok("0");#NormalTok("] ");#OperatorTok("+");#NormalTok(" v[");#DecValTok("0");#NormalTok("] ");#OperatorTok("*");#NormalTok(" scale ");#OperatorTok("*");#NormalTok(" ");#FloatTok("1.5");#NormalTok(",");],
[#NormalTok("        ols.coef_[");#DecValTok("1");#NormalTok("] ");#OperatorTok("+");#NormalTok(" v[");#DecValTok("1");#NormalTok("] ");#OperatorTok("*");#NormalTok(" scale ");#OperatorTok("*");#NormalTok(" ");#FloatTok("1.5");#NormalTok(",");],
[#NormalTok("        ");#VerbatimStringTok("r\"");#DecValTok("$");#VerbatimStringTok("v_{}");#DecValTok("$");#VerbatimStringTok(" ");#KeywordTok("(");#DecValTok("$");#ErrorTok("\\");#VerbatimStringTok("lambda={:");#DecValTok(".");#VerbatimStringTok("2f}");#DecValTok("$");#KeywordTok(")");#VerbatimStringTok("\"");#NormalTok(".");#BuiltInTok("format");#NormalTok("(i ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(", eigenvalues[i]),");],
[#NormalTok("        color");#OperatorTok("=");#StringTok("\"darkorange\"");#NormalTok(",");],
[#NormalTok("        fontweight");#OperatorTok("=");#StringTok("\"bold\"");#NormalTok(",");],
[#NormalTok("        ha");#OperatorTok("=");#StringTok("\"center\"");#NormalTok(",");],
[#NormalTok("    )");],
[#NormalTok("ax.legend()");],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-12-output-1.svg"))

]
, 
title: 
[
Gram matrix and Covariance matrix
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Choosing $lambda$
<choosing-lambda>
The regularization parameter $lambda$ determines how much shrinkage is applied.

In practice, the modern standard is to choose $lambda$ by cross-validation. Similar to the model selection procedure discussed in the linear regression case, the process works as follows:

+ Fix a value of $lambda$. Split the dataset into $k$ folds. Each time, choose one fold as the validation set and use the remaining folds as the training set to fit the model and compute the validation score.
+ Repeat this process so that each fold serves once as the validation set. The average validation score is the cross-validation score for this $lambda$.
+ Repeat the above steps for each candidate value of $lambda$, and select the $lambda$ with the best cross-validation score.
+ Finally, refit the model on the entire training set using the selected $lambda$.

Since this procedure is very common in ridge regression, sklearn provides #NormalTok("RidgeCV");, which has built-in cross-validation. Alternatively, the same task can be performed using #NormalTok("GridSearchCV");.

#block[
#callout(
body: 
[
#NormalTok("GridSearchCV"); typically uses $k$-fold cross-validation, where the training set is split into $k$ folds and each fold is used once as the validation set.

If each observation is treated as its own fold (that is, the validation set contains exactly one observation), the procedure is called leave-one-out cross-validation (LOOCV). In other words, LOOCV is equivalent to $N$-fold cross-validation, where $N$ is the number of observations.

#NormalTok("RidgeCV"); uses leave-one-out cross-validation by default.

]
, 
title: 
[
Leave-one-out cross-validation
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
The arguments of #NormalTok("RidgeCV"); are similar to those of #NormalTok("Ridge");. The main differences are:

- #NormalTok("alphas"); should be a list of candidate values for $alpha$. In the example below, $alpha$ is selected from values ranging from #NormalTok("1e-4"); to #NormalTok("1e4");.
- #NormalTok("cv"); works in the same way as in ordinary cross-validation and specifies the number of folds used in the cross-validation procedure. If it is not set, LOOCV will be used.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" RidgeCV");],
[#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[],
[#NormalTok("alphas ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[],
[#NormalTok("ridge_cv_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", RidgeCV(alphas");#OperatorTok("=");#NormalTok("alphas)),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("ridge_cv_pipe.fit(X, y)");],
[],
[#NormalTok("best_alpha_ridge ");#OperatorTok("=");#NormalTok(" ridge_cv_pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].alpha_");],
[#NormalTok("best_alpha_ridge");],));
#Skylighting(([#NormalTok("1.3219411484660315");],));
=== Validation curve and Coefficient paths
<validation-curve-and-coefficient-paths>
#NormalTok("RidgeCV"); returns only the final fitted model at the selected value of #NormalTok("alpha");, rather than the entire validation curve or coefficient path. If we want to examine how the validation score changes with #NormalTok("alpha");, we may fit ordinary Ridge models over a grid of #NormalTok("alpha"); values and then add a vertical line at the value selected by #NormalTok("RidgeCV");.

#NormalTok("sklearn"); provides #NormalTok("validation_curve()"); to streamline the process.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" validation_curve");],
[],
[#NormalTok("alphas ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[],
[#NormalTok("ridge_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", Ridge()),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[#NormalTok("train_scores, test_scores ");#OperatorTok("=");#NormalTok(" validation_curve(");],
[#NormalTok("    ridge_pipe,");],
[#NormalTok("    X,");],
[#NormalTok("    y,");],
[#NormalTok("    param_name");#OperatorTok("=");#StringTok("\"model__alpha\"");#NormalTok(",");],
[#NormalTok("    param_range");#OperatorTok("=");#NormalTok("alphas,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    scoring");#OperatorTok("=");#StringTok("\"neg_mean_squared_error\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("plt.plot(alphas, train_scores.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"train\"");#NormalTok(")");],
[#NormalTok("plt.plot(alphas, test_scores.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"test\"");#NormalTok(")");],
[#NormalTok("plt.axvline(");],
[#NormalTok("    best_alpha_ridge, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"RidgeCV alpha\"");],
[#NormalTok(")");],
[#NormalTok("plt.xscale(");#StringTok("\"log\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"alpha\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"score\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Validation curve for ridge regression\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#block[
/ Line 19: #block[
The validatiaon curve can also be drawn by #NormalTok("GridSearchCV.cv_results_");. There are no major difference between the two methods.
]

]
#box(image("contents\\1/shrinkage_files/figure-typst/cell-14-output-1.svg"))

Similarly, if we want to examine how the coefficients change with #NormalTok("alpha");, we fit ordinary #NormalTok("Ridge"); repeatedly over a grid of #NormalTok("alpha"); values and record the fitted coefficients. In this case, cross-validation is not needed, since the goal is only to visualize the coefficient path rather than to compare models.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Ridge");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("alphas ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[#NormalTok("coefs ");#OperatorTok("=");#NormalTok(" []");],
[#ControlFlowTok("for");#NormalTok(" a ");#KeywordTok("in");#NormalTok(" alphas:");],
[#NormalTok("    pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("        [");],
[#NormalTok("            (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("            (");#StringTok("\"model\"");#NormalTok(", Ridge(alpha");#OperatorTok("=");#NormalTok("a)),");],
[#NormalTok("        ]");],
[#NormalTok("    )");],
[#NormalTok("    pipe.fit(X, y)");],
[#NormalTok("    coefs.append(pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].coef_)");],
[#NormalTok("coefs ");#OperatorTok("=");#NormalTok(" np.array(coefs)");],
[#ControlFlowTok("for");#NormalTok(" j ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(coefs.shape[");#DecValTok("1");#NormalTok("]):");],
[#NormalTok("    plt.plot(alphas, coefs[:, j], label");#OperatorTok("=");#SpecialStringTok("f\"x");#SpecialCharTok("{");#NormalTok("j ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.axvline(best_alpha_ridge, linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"RidgeCV alpha\"");#NormalTok(")");],
[],
[#NormalTok("ax ");#OperatorTok("=");#NormalTok(" plt.gca()");],
[#NormalTok("ax.set_xlim(ax.get_xlim()[::");#OperatorTok("-");#DecValTok("1");#NormalTok("])");],
[#NormalTok("plt.xscale(");#StringTok("\"log\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"alpha\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"weights\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Ridge Coefficients vs Regularization Strength (alpha)\"");#NormalTok(")");],
[#NormalTok("plt.axis(");#StringTok("\"tight\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#block[
/ Line 21: #block[
In the coefficient path plot, the horizontal axis is shown in reverse order so that the coefficients move from heavily regularized models on the left to weakly regularized models on the right.
]

]
#box(image("contents\\1/shrinkage_files/figure-typst/cell-15-output-1.svg"))

=== LOOCV
<loocv>
Naively, LOOCV would require fitting the model $N$ times. Each time one observation is removed and the model is refit. However, ridge regression admits an analytic formula that allows the LOOCV error to be computed without refitting the model repeatedly. This is one reason ridge regression works very well with LOOCV. #NormalTok("RidgeCV"); from #NormalTok("sklearn"); is also implemented using LOOCV formula instead of refitting the model multiple times.

#theorem(title: [LOOCV])[
The LOOCV error is \$\$
\\text{CV}(\\lambda)
=
\\frac{1}{N}
\\sum\_{i=1}^{N}
\\qty(
\\frac{y\_i - \\hat{y}\_i}{1 - H\_{\\lambda,ii}}
)^2.
\$\$

Click for proof.
Recall that the ridge estimator is $ hat(beta)_lambda = \( X^top X + lambda I \)^(- 1) X^top y . $

The fitted values can be written as $ hat(y) = X hat(beta)_lambda = H_lambda y \, $ where $ H_lambda = X \( X^top X + lambda I \)^(- 1) X^top $ is the ridge hat matrix.

Let

$ r_i = y_i - hat(y)_i $

be the ordinary residual from the ridge regression fitted using the entire dataset.

Suppose we remove observation $i$ and refit the ridge regression model. Let $hat(y)_(\( i \))$ denote the predicted value for $y_i$ from this leave-one-out model. The corresponding leave-one-out residual is

$ r_(\( i \)) = y_i - hat(y)_(\( i \)) . $

By the PRESS residual formula #cite(<Allen1974>, form: "prose"), this residual can be computed directly from the full-data fit: $ r_(\( i \)) = frac(r_i, 1 - H_(lambda \, i i)) \, $

where $H_(lambda \, i i)$ is the $i$-th diagonal element of the ridge hat matrix.

Therefore the LOOCV error is \$\$
\\text{CV}(\\lambda)
=
\\frac{1}{N}
\\sum\_{i=1}^{N}
\\qty(
\\frac{y\_i - \\hat{y}\_i}{1 - H\_{\\lambda,ii}}
)^2.
\$\$

] <thm->
#block[
#callout(
body: 
[
This formula means that the leave-one-out residuals can be obtained by simply adjusting the ordinary residuals using the leverage term $H_(lambda \, i i)$. Consequently, the LOOCV error can be computed without refitting the model $N$ times.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Lasso Regression
<lasso-regression>
=== Definition
<definition>
Lasso regression (short for least absolute shrinkage and selection operator) modifies the OLS objective by adding an $L_1$ penalty.

#definition(title: [Lasso Regression])[
For a response vector $y in bb(R)^n$ and a design matrix $X in bb(R)^(n times p)$, the lasso estimator \$\\hat{\\beta}\_{\\lasso}\$ is defined by

\$\$
\\hat{\\beta}\_{\\lasso}
=
\\arg\\min\_{\\beta}
\\qty{
\\norm{y-X\\beta}\_2^2 + \\lambda \\norm{\\beta}\_1
}
\$\$

where

- $lambda gt.eq 0$ is the regularization parameter,
- \$\\norm{\\beta}\_1 = \\sum\_{j=1}^p |\\beta\_j|\$ is the $L_1$ norm of the coefficient vector.

] <def-lasso>
#block[
#callout(
body: 
[
Lasso is solved using numerical optimization algorithms. The most widely used methods include

- coordinate descent
- LARS (Least Angle Regression)
- proximal gradient methods

These algorithms iteratively update the coefficients until convergence.

Unlike OLS or ridge regression, the lasso estimator does not admit a closed-form solution because the $L_1$ penalty is not differentiable at zero.

]
, 
title: 
[
Solving lasso
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
The lasso penalty also shrinks the coefficients toward zero, and therefore behaves similarly to ridge regression. In practice, the penalty is typically applied only to the slope coefficients, so the intercept is not penalized. For this reason, it is common to standardize the predictors and center the response variable before fitting the model.

However, lasso has an important difference from ridge regression, which we discuss in the next section.

=== Geometry and sparsity
<geometry-and-sparsity>
Similar to ridge regression, by the theory of Lagrange multipliers, lasso can also be written in constrained form:

\$\$
\\hat{\\beta}\_{\\lasso}
=
\\arg\\min\_{\\beta}
\\norm{y-X\\beta}\_2^2
\\quad
\\text{subject to}
\\quad
\\norm{\\beta}\_1 \\le s.
\$\$

Here $s gt.eq 0$ controls the size of the coefficient vector. This constrained formulation is useful because it makes the geometry of lasso easier to visualize.

In $bb(R)^2$, the ridge constraint region is based on the $L_2$ norm and has a circular boundary, whereas the lasso constraint region is based on the $L_1$ norm and has a diamond-shaped boundary. The solution is obtained where the smallest residual \$\\rss\$ contour first touches the constraint region.

For ridge regression, the circular boundary is smooth, so the point of tangency typically occurs away from the coordinate axes. As a result, ridge usually shrinks coefficients continuously toward zero, but does not make them exactly zero.

For lasso, the diamond-shaped boundary has sharp corners lying on the coordinate axes. Because of these corners, the point of tangency is much more likely to occur at a location where one coordinate is zero. Consequently, lasso can produce solutions with some coefficients exactly equal to zero.

Therefore, ridge is mainly a shrinkage method, whereas lasso is both a shrinkage method and a variable-selection method.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("mu ");#OperatorTok("=");#NormalTok(" np.array([");#FloatTok("2.0");#NormalTok(", ");#FloatTok("0.35");#NormalTok("])");],
[],
[#NormalTok("theta ");#OperatorTok("=");#NormalTok(" np.deg2rad(");#DecValTok("32");#NormalTok(")");],
[#NormalTok("R ");#OperatorTok("=");#NormalTok(" np.array([[np.cos(theta), ");#OperatorTok("-");#NormalTok("np.sin(theta)], [np.sin(theta), np.cos(theta)]])");],
[],
[#NormalTok("D ");#OperatorTok("=");#NormalTok(" np.diag([");#FloatTok("7.0");#NormalTok(", ");#FloatTok("0.45");#NormalTok("])");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" R ");#OperatorTok("@");#NormalTok(" D ");#OperatorTok("@");#NormalTok(" R.T");],
[],
[],
[#KeywordTok("def");#NormalTok(" rss(beta1, beta2):");],
[#NormalTok("    B ");#OperatorTok("=");#NormalTok(" np.stack([beta1 ");#OperatorTok("-");#NormalTok(" mu[");#DecValTok("0");#NormalTok("], beta2 ");#OperatorTok("-");#NormalTok(" mu[");#DecValTok("1");#NormalTok("]], axis");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" np.einsum(");#StringTok("\"...i,ij,...j->...\"");#NormalTok(", B, A, B)");],
[],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#FloatTok("0.5");#NormalTok(", ");#FloatTok("3.2");#NormalTok(", ");#DecValTok("600");#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#FloatTok("2.0");#NormalTok(", ");#FloatTok("2.0");#NormalTok(", ");#DecValTok("600");#NormalTok(")");],
[#NormalTok("X, Y ");#OperatorTok("=");#NormalTok(" np.meshgrid(x, y)");],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" rss(X, Y)");],
[],
[#NormalTok("levels ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.15");#NormalTok(", ");#FloatTok("0.4");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#FloatTok("1.4");#NormalTok(", ");#FloatTok("2.4");#NormalTok(", ");#FloatTok("3.8");#NormalTok(", ");#FloatTok("5.8");#NormalTok("]");],
[],
[#NormalTok("ridge_r ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.7");],
[#NormalTok("lasso_t ");#OperatorTok("=");#NormalTok(" ");#FloatTok("2.0");],
[],
[#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].contour(X, Y, Z, levels");#OperatorTok("=");#NormalTok("levels)");],
[#NormalTok("diamond ");#OperatorTok("=");#NormalTok(" np.array(");],
[#NormalTok("    [[lasso_t, ");#DecValTok("0");#NormalTok("], [");#DecValTok("0");#NormalTok(", lasso_t], [");#OperatorTok("-");#NormalTok("lasso_t, ");#DecValTok("0");#NormalTok("], [");#DecValTok("0");#NormalTok(", ");#OperatorTok("-");#NormalTok("lasso_t], [lasso_t, ");#DecValTok("0");#NormalTok("]]");],
[#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].plot(diamond[:, ");#DecValTok("0");#NormalTok("], diamond[:, ");#DecValTok("1");#NormalTok("], linewidth");#OperatorTok("=");#DecValTok("3");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].scatter(");#OperatorTok("*");#NormalTok("mu)");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].axhline(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].axvline(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"Lasso Constraint\"");#NormalTok(")");],
[],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].contour(X, Y, Z, levels");#OperatorTok("=");#NormalTok("levels)");],
[#NormalTok("t ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.pi, ");#DecValTok("400");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(ridge_r ");#OperatorTok("*");#NormalTok(" np.cos(t), ridge_r ");#OperatorTok("*");#NormalTok(" np.sin(t), linewidth");#OperatorTok("=");#DecValTok("3");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].scatter(");#OperatorTok("*");#NormalTok("mu)");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].axhline(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].axvline(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"Ridge Constraint\"");#NormalTok(")");],
[],
[#ControlFlowTok("for");#NormalTok(" ax ");#KeywordTok("in");#NormalTok(" axs:");],
[#NormalTok("    ax.set_xlim(");#OperatorTok("-");#FloatTok("2.2");#NormalTok(", ");#FloatTok("3.2");#NormalTok(")");],
[#NormalTok("    ax.set_ylim(");#OperatorTok("-");#DecValTok("2");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("    ax.set_aspect(");#StringTok("\"equal\"");#NormalTok(")");],
[#NormalTok("    ax.set_xlabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_1");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#VerbatimStringTok("r\"");#DecValTok("$\\b");#VerbatimStringTok("eta_2");#DecValTok("$");#VerbatimStringTok("\"");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-16-output-1.svg"))

=== One-variable lasso and soft-thresholding
<one-variable-lasso-and-soft-thresholding>
To understand how lasso sets coefficients to $0$, it is useful to first look at the one-variable case.

Suppose we want to solve \$\$
\\min\_{\\beta}\\qty{\\norm{y-X\\beta}\_2^2 + \\lambda \\abs{\\beta}}.
\$\$

Note that \$\$
\\hat\\beta\_\\ols=\\arg\\min\_\\beta\\qty{\\norm{y-X\\beta}\_2^2}
\$\$ denotes the OLS solution for this one-variable problem.

#theorem(title: [Soft-thresholding Rule])[
\$\$
\\hat\\beta\_\\lasso=\\begin{cases}
\\hat\\beta\_\\ols+\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\<-\\frac\\lambda{2a},\\\\
0& \\text{ if }\\abs{\\hat\\beta\_\\ols}\\leq\\frac\\lambda{2a},\\\\
\\hat\\beta\_\\ols-\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\> \\frac\\lambda{2a},\\\\
\\end{cases}
\$\$

Click to expand.
Since there is only one $beta$, \$\$
\\rss(\\beta)=\\norm{y-X\\beta}\_2^2+\\lambda\\abs{\\beta}=(\\sum x\_i^2)\\beta^2-2(\\sum x\_iy\_i)\\beta+\\sum y\_i^2+\\lambda\\abs{\\beta}.
\$\$

Let $a = sum x_i^2$, $c = sum x_i y_i$. Then \$\$
\\rss(\\beta)=a\\beta^2-2c\\beta+\\lambda\\abs{\\beta}+\\constant.
\$\$

Note that

\$\$
\\hat\\beta\_\\ols=(X^\\top X)^{-1}X^\\top y=\\frac{\\sum x\_iy\_i}{\\sum x\_i^2}=\\frac ca.
\$\$

Now due to absolute value we split into different cases.

#horizontalrule

If $beta gt.eq 0$: Then \$\\abs{\\beta}=\\beta\$. Therefore \$\\rss(\\beta)=a\\beta^2-2c\\beta+\\lambda\\beta+\\constant\$. Let \$\\dv{\\rss(\\beta)}{\\beta}=2a\\beta-2c+\\lambda=0\$. So \$\\beta=\\frac ca-\\frac{\\lambda}{2a}=\\hat\\beta\_\\ols-\\frac\\lambda {2a}\$ is the critical point.

In this case since $beta gt.eq 0$,

- if \$\\hat\\beta\_\\ols+\\frac\\lambda {2a}\>0\$, then the minimizer is \$\\hat\\beta\_\\ols+\\frac\\lambda {2a}\$.
- Otherwise, the minimum over the region $beta gt.eq 0$ is attained at $0$.

Therefore \$\$
\\hat\\beta\_\\lasso=\\begin{cases}
\\hat\\beta\_\\ols-\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\> \\frac\\lambda{2a},\\\\
0& \\text{ if }\\hat\\beta\_\\ols\\leq \\frac\\lambda{2a}.
\\end{cases}
\$\$

#horizontalrule

If $beta lt.eq 0$: Then \$\\abs{\\beta}=-\\beta\$. Therefore \$\\rss(\\beta)=a\\beta^2-2c\\beta-\\lambda\\beta+\\constant\$. Let \$\\dv{\\rss(\\beta)}{\\beta}=2a\\beta-2c-\\lambda=0\$. So \$\\beta=\\frac ca+\\frac{\\lambda}{2a}=\\hat\\beta\_\\ols+\\frac\\lambda {2a}\$ is the critical point.

In this case since $beta lt.eq 0$,

- if \$\\hat\\beta\_\\ols+\\frac\\lambda {2a}\<0\$, then the minimizer is \$\\hat\\beta\_\\ols+\\frac\\lambda {2a}\$.
- Otherwise, the minimum over the region $beta lt.eq 0$ is attained at $0$.

In other words, \$\$
\\hat\\beta\_\\lasso=\\begin{cases}
\\hat\\beta\_\\ols+\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\<-\\frac\\lambda{2a},\\\\
0& \\text{ if }\\hat\\beta\_\\ols\\geq -\\frac\\lambda{2a}
\\end{cases}
\$\$

#horizontalrule

To sum up,

\$\$
\\hat\\beta\_\\lasso=\\begin{cases}
\\hat\\beta\_\\ols+\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\<-\\frac\\lambda{2a},\\\\
0& \\text{ if }\\abs{\\hat\\beta\_\\ols}\\leq\\frac\\lambda{2a},\\\\
\\hat\\beta\_\\ols-\\frac\\lambda{2a}& \\text{ if }\\hat\\beta\_\\ols\> \\frac\\lambda{2a},\\\\
\\end{cases}
\$\$

] <thm->
This formula shows the essential behavior of lasso:

- if the OLS coefficient is large enough in magnitude, it is shrunk toward zero;
- if the OLS coefficient is small enough, it is shrunk all the way to zero.

#block[
#callout(
body: 
[
If the design matrix satisfies $X^top X = n I$, then the lasso problem separates into $p$ one-variable problems. In that case, each lasso coefficient is obtained by applying soft-thresholding to the corresponding OLS coefficient.

This is the clearest way to see why lasso performs variable selection.

]
, 
title: 
[
Orthogonal design
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Lasso in Python
<lasso-in-python>
In #NormalTok("scikit-learn");, #NormalTok("Lasso"); and #NormalTok("LassoCV"); from #NormalTok("linear_model"); are used in a way very similar to #NormalTok("Ridge"); and #NormalTok("RidgeCV");.

- The argument #NormalTok("alpha"); is the regularization parameter.
- #NormalTok("fit_intercept=True"); means the intercept is handled automatically.
- If #NormalTok("fit_intercept=False");, the data is expected to be centered beforehand.
- It is recommended to standardize the features $X$.

A key computational difference from ridge is that lasso does not have a closed-form estimator. Likewise, unlike ridge regression, there is no closed-form LOOCV formula available for selecting the tuning parameter. Therefore, #NormalTok("LassoCV"); uses ordinary $K$-fold cross-validation to choose the best value of #NormalTok("alpha");.

=== A simulated example
<a-simulated-example>
To illustrate lasso and ridge in code, we start with a simulated dataset. The data are constructed so that:

- there are 100 predictors and 150 observations,
- many predictors are almost collinear (that they are obtained from a rank 12 latent structure),
- but only 10 predictors truly contribute to the response.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("150");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("12");],
[],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, k))");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(k, p))");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" Z ");#OperatorTok("@");#NormalTok(" A ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, p))");],
[],
[#NormalTok("beta ");#OperatorTok("=");#NormalTok(" np.zeros(p)");],
[#NormalTok("beta[:");#DecValTok("10");#NormalTok("] ");#OperatorTok("=");#NormalTok(" [");#DecValTok("8");#NormalTok(", ");#DecValTok("7");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#FloatTok("0.5");#NormalTok("]");],
[],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("@");#NormalTok(" beta ");#OperatorTok("+");#NormalTok(" ");#DecValTok("12");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("n)");],));
]
We split the data into training and test sets.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");],
[#NormalTok(")");],));
]
=== Initial model fitting
<initial-model-fitting>
Before tuning the regularization parameter, we first fit OLS, ridge, and lasso with simple default or manually chosen settings. This gives a first look at how the methods behave on the same dataset.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" mean_squared_error, r2_score");],
[],
[#NormalTok("ols_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", LinearRegression()),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("ols_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_ols ");#OperatorTok("=");#NormalTok(" ols_pipe.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"OLS\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_ols)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_ols)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("OLS");],
[#NormalTok("Test RMSE: 1212.515485649412");],
[#NormalTok("Test R^2 : 0.49121698288112325");],));
]
]
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Ridge");],
[],
[#NormalTok("ridge_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", Ridge(alpha");#OperatorTok("=");#FloatTok("1.0");#NormalTok(")),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[#NormalTok("ridge_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_ridge ");#OperatorTok("=");#NormalTok(" ridge_pipe.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Ridge\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_ridge)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_ridge)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Ridge");],
[#NormalTok("Test RMSE: 249.13745912332723");],
[#NormalTok("Test R^2 : 0.8954595552549109");],));
]
]
#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Lasso");],
[],
[#NormalTok("lasso_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", Lasso(alpha");#OperatorTok("=");#FloatTok("0.1");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("10000");#NormalTok(")),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[#NormalTok("lasso_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_lasso ");#OperatorTok("=");#NormalTok(" lasso_pipe.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"");#CharTok("\\n");#StringTok("Lasso\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_lasso)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_lasso)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("Lasso");],
[#NormalTok("Test RMSE: 204.53280796906878");],
[#NormalTok("Test R^2 : 0.9141760906397303");],));
]
]
One important difference between ridge and lasso is that lasso can set some coefficients exactly to zero, while ridge typically only shrinks coefficients toward zero without eliminating them.

#block[
#Skylighting(([#NormalTok("ridge_coef ");#OperatorTok("=");#NormalTok(" ridge_pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].coef_");],
[#NormalTok("lasso_coef ");#OperatorTok("=");#NormalTok(" lasso_pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].coef_");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Number of nonzero ridge coefficients:\"");#NormalTok(", np.");#BuiltInTok("sum");#NormalTok("(ridge_coef ");#OperatorTok("!=");#NormalTok(" ");#DecValTok("0");#NormalTok("))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Number of nonzero lasso coefficients:\"");#NormalTok(", np.");#BuiltInTok("sum");#NormalTok("(lasso_coef ");#OperatorTok("!=");#NormalTok(" ");#DecValTok("0");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Number of nonzero ridge coefficients: 100");],
[#NormalTok("Number of nonzero lasso coefficients: 64");],));
]
]
You can see that in the lasso case, many coefficients are exactly $0$. This is one reason lasso is often viewed as performing both regularization and variable selection.

=== Coefficient paths
<coefficient-paths>
To better understand how the regularization parameter affects the estimates, we now plot the coefficient paths.

- In the lasso plot, some coefficient curves hit exactly $0$ as #NormalTok("alpha"); increases.
- In the ridge plot, all coefficients are shrunk continuously toward $0$, but usually remain nonzero.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" lasso_path, Ridge");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[],
[#NormalTok("scaler ");#OperatorTok("=");#NormalTok(" StandardScaler()");],
[#NormalTok("X_train_scaled ");#OperatorTok("=");#NormalTok(" scaler.fit_transform(X_train)");],
[],
[#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[],
[],
[#NormalTok("alphas_lasso, coefs_lasso, _ ");#OperatorTok("=");#NormalTok(" lasso_path(X_train_scaled, y_train)");],
[],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].plot(alphas_lasso, coefs_lasso.T)");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"Lasso coefficient paths\"");#NormalTok(")");],
[],
[#NormalTok("alphas_ridge ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[#NormalTok("coefs_ridge ");#OperatorTok("=");#NormalTok(" []");],
[#ControlFlowTok("for");#NormalTok(" a ");#KeywordTok("in");#NormalTok(" alphas_ridge:");],
[#NormalTok("    ridge ");#OperatorTok("=");#NormalTok(" Ridge(alpha");#OperatorTok("=");#NormalTok("a)");],
[#NormalTok("    ridge.fit(X_train_scaled, y_train)");],
[#NormalTok("    coefs_ridge.append(ridge.coef_)");],
[#NormalTok("coefs_ridge ");#OperatorTok("=");#NormalTok(" np.array(coefs_ridge)");],
[],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(alphas_ridge, coefs_ridge)");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"Ridge coefficient paths\"");#NormalTok(")");],
[],
[#ControlFlowTok("for");#NormalTok(" ax ");#KeywordTok("in");#NormalTok(" axs:");],
[#NormalTok("    ax.set_xscale(");#StringTok("\"log\"");#NormalTok(")");],
[#NormalTok("    ax.axhline(");#DecValTok("0");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", linewidth");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ax.invert_xaxis()");],
[#NormalTok("    ax.set_ylim(");#OperatorTok("-");#DecValTok("40");#NormalTok(", ");#DecValTok("40");#NormalTok(")");],
[#NormalTok("    ax.set_xlabel(");#StringTok("\"alpha\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#StringTok("\"coefficient\"");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-23-output-1.svg"))

=== Tuning with cross-validation
<tuning-with-cross-validation>
The choice of #NormalTok("alpha"); strongly affects the fitted model. Therefore in practice we usually tune it by cross-validation.

We first use #NormalTok("LassoCV"); to select the best value of alpha.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LassoCV");],
[],
[#NormalTok("lasso_cv_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", LassoCV(cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("10000");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(")),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("lasso_cv_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_lasso_cv ");#OperatorTok("=");#NormalTok(" lasso_cv_pipe.predict(X_test)");],
[],
[#NormalTok("best_alpha_lasso ");#OperatorTok("=");#NormalTok(" lasso_cv_pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].alpha_");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best lasso alpha:\"");#NormalTok(", best_alpha_lasso)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"LassoCV Test RMSE:\"");#NormalTok(", mean_squared_error(y_test, y_pred_lasso_cv))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"LassoCV Test R^2 :\"");#NormalTok(", r2_score(y_test, y_pred_lasso_cv))");],));
#block[
#Skylighting(([#NormalTok("Best lasso alpha: 0.4608014833934263");],
[#NormalTok("LassoCV Test RMSE: 221.76483520224215");],
[#NormalTok("LassoCV Test R^2 : 0.9069453683021322");],));
]
]
For comparison, we also fit ridge regression with #NormalTok("RidgeCV");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" RidgeCV");],
[],
[#NormalTok("ridge_cv_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", RidgeCV()),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("ridge_cv_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_ridge_cv ");#OperatorTok("=");#NormalTok(" ridge_cv_pipe.predict(X_test)");],
[],
[#NormalTok("best_alpha_ridge ");#OperatorTok("=");#NormalTok(" ridge_cv_pipe.named_steps[");#StringTok("\"model\"");#NormalTok("].alpha_");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best lasso alpha:\"");#NormalTok(", best_alpha_ridge)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"LassoCV Test RMSE:\"");#NormalTok(", mean_squared_error(y_test, y_pred_ridge_cv))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"LassoCV Test R^2 :\"");#NormalTok(", r2_score(y_test, y_pred_ridge_cv))");],));
#block[
#Skylighting(([#NormalTok("Best lasso alpha: 10.0");],
[#NormalTok("LassoCV Test RMSE: 274.2521785548484");],
[#NormalTok("LassoCV Test R^2 : 0.8849211803824286");],));
]
]
After obtaining the best regularization parameters, we mark them on the coefficient path plots. This helps connect the selected model to the whole regularization path.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" lasso_path, Ridge");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[],
[#NormalTok("scaler ");#OperatorTok("=");#NormalTok(" StandardScaler()");],
[#NormalTok("X_train_scaled ");#OperatorTok("=");#NormalTok(" scaler.fit_transform(X_train)");],
[],
[#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[],
[],
[#NormalTok("alphas_lasso, coefs_lasso, _ ");#OperatorTok("=");#NormalTok(" lasso_path(X_train_scaled, y_train)");],
[],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].plot(alphas_lasso, coefs_lasso.T)");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].axvline(");],
[#NormalTok("    best_alpha_lasso, linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"LassoCV alpha\"");],
[#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"Lasso coefficient paths\"");#NormalTok(")");],
[],
[#NormalTok("alphas_ridge ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[#NormalTok("coefs_ridge ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" a ");#KeywordTok("in");#NormalTok(" alphas_ridge:");],
[#NormalTok("    ridge ");#OperatorTok("=");#NormalTok(" Ridge(alpha");#OperatorTok("=");#NormalTok("a)");],
[#NormalTok("    ridge.fit(X_train_scaled, y_train)");],
[#NormalTok("    coefs_ridge.append(ridge.coef_)");],
[],
[#NormalTok("coefs_ridge ");#OperatorTok("=");#NormalTok(" np.array(coefs_ridge)");],
[],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(alphas_ridge, coefs_ridge)");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].axvline(");],
[#NormalTok("    best_alpha_ridge, linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"RidgeCV alpha\"");],
[#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"Ridge coefficient paths\"");#NormalTok(")");],
[],
[#ControlFlowTok("for");#NormalTok(" ax ");#KeywordTok("in");#NormalTok(" axs:");],
[#NormalTok("    ax.set_xscale(");#StringTok("\"log\"");#NormalTok(")");],
[#NormalTok("    ax.axhline(");#DecValTok("0");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", linewidth");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ax.invert_xaxis()");],
[#NormalTok("    ax.set_ylim(");#OperatorTok("-");#DecValTok("40");#NormalTok(", ");#DecValTok("40");#NormalTok(")");],
[#NormalTok("    ax.set_xlabel(");#StringTok("\"alpha\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#StringTok("\"coefficient\"");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-26-output-1.svg"))

=== Validation curves
<validation-curves>
Another way to visualize tuning is through the validation curve. Here we plot the mean training and validation scores across a grid of #NormalTok("alpha"); values. Note that the score is nagative MSE. Therefore the higher the better.

- When #NormalTok("alpha"); is too small, the model may overfit.
- When #NormalTok("alpha"); is too large, the model may underfit.
- A good value of #NormalTok("alpha"); balances these two effects.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" validation_curve");],
[#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" Ridge, Lasso");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("alphas ");#OperatorTok("=");#NormalTok(" np.logspace(");#OperatorTok("-");#DecValTok("4");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("100");#NormalTok(")");],
[],
[#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#FloatTok("4.5");#NormalTok("))");],
[],
[#NormalTok("lasso_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", Lasso(max_iter");#OperatorTok("=");#DecValTok("20000");#NormalTok(")),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("train_scores_lasso, test_scores_lasso ");#OperatorTok("=");#NormalTok(" validation_curve(");],
[#NormalTok("    lasso_pipe,");],
[#NormalTok("    X,");],
[#NormalTok("    y,");],
[#NormalTok("    param_name");#OperatorTok("=");#StringTok("\"model__alpha\"");#NormalTok(",");],
[#NormalTok("    param_range");#OperatorTok("=");#NormalTok("alphas,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    scoring");#OperatorTok("=");#StringTok("\"neg_mean_squared_error\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].plot(alphas, train_scores_lasso.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"train\"");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].plot(alphas, test_scores_lasso.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"test\"");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].axvline(");],
[#NormalTok("    best_alpha_lasso, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best alpha\"");],
[#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"Validation curve for lasso\"");#NormalTok(")");],
[],
[],
[#NormalTok("ridge_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", Ridge()),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("train_scores_ridge, test_scores_ridge ");#OperatorTok("=");#NormalTok(" validation_curve(");],
[#NormalTok("    ridge_pipe,");],
[#NormalTok("    X,");],
[#NormalTok("    y,");],
[#NormalTok("    param_name");#OperatorTok("=");#StringTok("\"model__alpha\"");#NormalTok(",");],
[#NormalTok("    param_range");#OperatorTok("=");#NormalTok("alphas,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    scoring");#OperatorTok("=");#StringTok("\"neg_mean_squared_error\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(alphas, train_scores_ridge.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"train\"");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(alphas, test_scores_ridge.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok("), label");#OperatorTok("=");#StringTok("\"test\"");#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].axvline(");],
[#NormalTok("    best_alpha_ridge, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best alpha\"");],
[#NormalTok(")");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"Validation curve for ridge\"");#NormalTok(")");],
[],
[],
[#ControlFlowTok("for");#NormalTok(" ax ");#KeywordTok("in");#NormalTok(" axs:");],
[#NormalTok("    ax.set_xscale(");#StringTok("\"log\"");#NormalTok(")");],
[#NormalTok("    ax.set_xlabel(");#StringTok("\"alpha\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#StringTok("\"score: Nagative MSE\"");#NormalTok(")");],
[#NormalTok("    ax.legend()");],
[],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/shrinkage_files/figure-typst/cell-27-output-1.svg"))

=== Summary
<summary>
Finally, we summarize the test performance and the number of nonzero coefficients for each model.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#NormalTok("results ");#OperatorTok("=");#NormalTok(" []");],
[],
[#NormalTok("models ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"OLS\"");#NormalTok(": ols_pipe,");],
[#NormalTok("    ");#StringTok("\"RidgeCV\"");#NormalTok(": ridge_cv_pipe,");],
[#NormalTok("    ");#StringTok("\"LassoCV\"");#NormalTok(": lasso_cv_pipe,");],
[#NormalTok("}");],
[],
[#ControlFlowTok("for");#NormalTok(" name, model ");#KeywordTok("in");#NormalTok(" models.items():");],
[#NormalTok("    y_pred ");#OperatorTok("=");#NormalTok(" model.predict(X_test)");],
[#NormalTok("    rmse ");#OperatorTok("=");#NormalTok(" mean_squared_error(y_test, y_pred)");],
[#NormalTok("    r2 ");#OperatorTok("=");#NormalTok(" r2_score(y_test, y_pred)");],
[],
[#NormalTok("    n_nonzero ");#OperatorTok("=");#NormalTok(" np.");#BuiltInTok("sum");#NormalTok("(model.named_steps[");#StringTok("\"model\"");#NormalTok("].coef_ ");#OperatorTok("!=");#NormalTok(" ");#DecValTok("0");#NormalTok(")    ");],
[#NormalTok("    alpha ");#OperatorTok("=");#NormalTok(" model.named_steps[");#StringTok("\"model\"");#NormalTok("].alpha_ ");#ControlFlowTok("if");#NormalTok(" name ");#OperatorTok("!=");#NormalTok(" ");#StringTok("\"OLS\"");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#VariableTok("None");],
[],
[#NormalTok("    results.append({");],
[#NormalTok("        ");#StringTok("'Model'");#NormalTok(": name,");],
[#NormalTok("        ");#StringTok("'Best alpha'");#NormalTok(": alpha,");],
[#NormalTok("        ");#StringTok("'Test RMSE'");#NormalTok(": rmse,");],
[#NormalTok("        ");#StringTok("'Test R^2'");#NormalTok(": r2,");],
[#NormalTok("        ");#StringTok("'Nonzero coefs'");#NormalTok(": n_nonzero");],
[#NormalTok("    })");],
[],
[#NormalTok("pd.DataFrame(results)");],));
#table(
  columns: 6,
  align: (auto,auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[Model], table.cell(align: right)[Best alpha], table.cell(align: right)[Test RMSE], table.cell(align: right)[Test R^2], table.cell(align: right)[Nonzero coefs],),
  table.hline(),
  table.cell(align: horizon)[0], [OLS], [NaN], [1212.515486], [0.491217], [100],
  table.cell(align: horizon)[1], [RidgeCV], [10.000000], [274.252179], [0.884921], [100],
  table.cell(align: horizon)[2], [LassoCV], [0.460801], [221.764835], [0.906945], [27],
)
This example shows the main practical difference between ridge and lasso:

- Ridge shrinks coefficients continuously and is especially useful when predictors are strongly correlated.
- Lasso also shrinks coefficients, but can force some of them to be exactly zero, producing a sparse model.

In high-dimensional settings with collinearity and only a subset of truly relevant predictors, lasso often provides a more interpretable model, while ridge often gives more stable coefficient estimates.

= Dimension reduction
<dimension-reduction>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
When the number of predictors is large or when predictors are highly correlated, directly fitting a regression model using the original predictors may lead to unstable estimates and poor predictive performance.

One approach to address this problem is dimension reduction. Instead of using the original predictors directly, we first construct a smaller number of derived variables (called components) and then perform regression using these components.

Two commonly used methods are

- Principal Component Regression (PCR)
- Partial Least Squares (PLS)

Both methods construct new variables that are linear combinations of the original predictors, but they differ in how those combinations are chosen.

== Principal Component Regression (PCR)
<principal-component-regression-pcr>
PCR first applies principal component analysis (PCA) to the predictor matrix $X$, and then uses the leading principal components as predictors in a regression model.

The key idea is that most of the variation in the predictors often lies in a lower-dimensional subspace.

#definition(title: [Principal Component Regression])[
Let $X$ be the $n times p$ predictor matrix.

The principal components are defined as

$ Z_k = X v_k \, $

where $v_k$ is the $k$-th eigenvector of the Gram matrix $X^top X$.

Principal component regression fits a linear model using the first $m$ components:

$ y = theta_0 + theta_1 Z_1 + theta_2 Z_2 + dots.h.c + theta_m Z_m + epsilon . $

Here

- $Z_1 \, dots.h \, Z_m$ are the first $m$ principal components
- $m < p$ is chosen by cross-validation

] <def-pcr>
Thus PCR replaces the original predictors with a smaller set of orthogonal components.

#block[
#callout(
body: 
[
PCR constructs components using only the predictor matrix $X$, without considering the response $y$.

As a result, the directions that explain the most variation in $X$ are not necessarily the directions that are most predictive of $y$.

]
, 
title: 
[
Key feature of PCR
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Data matrix and its geometric views
<data-matrix-and-its-geometric-views>
Let $X in bb(R)^(n times p)$ be a data matrix with $n$ observations and $p$ predictors. We assume columns are centered ($sum_(i = 1)^n x_(i j) = 0$) so that the origin represents the sample mean.

#strong[Column (variable) view: observation space $bb(R)^n$]

Each column of $X_j$ is a vector in $n$-dimensional space, which represents one predictor across all observations.

- This space is often called the observation space.
- Geometry in this space describes relationships between predictors:
  - Inner products encode covariance.
  - After standardization, angles encode correlation.
  - Orthogonality corresponds to zero correlation.

#strong[Row (observation) view: feature space $bb(R)^p$]

Each row of $x_i^top$ is a vector in $p$-dimensional space, which represents one observation across all predictors.

- This space is called the feature space.
- Geometry in this space describes relationships between observations:
  - Euclidean distance measures dissimilarity.
  - Clustering and nearest-neighbor methods operate in this space.

#example()[
~

Click to expand.
To demonstrate the idea, we generate the following dataset. It contains 2 variables.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[],
[#NormalTok("Sigma ");#OperatorTok("=");#NormalTok(" np.array([[");#FloatTok("0.5");#NormalTok(", ");#OperatorTok("-");#FloatTok("0.65");#NormalTok("], [");#OperatorTok("-");#FloatTok("0.65");#NormalTok(", ");#FloatTok("1.0");#NormalTok("]])");],
[#NormalTok("mu ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("])");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.multivariate_normal(mean");#OperatorTok("=");#NormalTok("mu, cov");#OperatorTok("=");#NormalTok("Sigma, size");#OperatorTok("=");#NormalTok("n)");],
[],
[#NormalTok("plt.scatter(X[:, ");#DecValTok("0");#NormalTok("], X[:, ");#DecValTok("1");#NormalTok("])");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"x1\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"x2\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0, 0.5, 'x2')");],));
#block[
#box(image("contents\\1/dr_files/figure-typst/cell-2-output-2.svg"))

]
Each point is an observation and is represented by a point in the feature space.

] <exm->

#horizontalrule

=== Singular Value Decomposition (SVD)
<singular-value-decomposition-svd>
The SVD provides the most direct link between the two geometric perspectives.

For a matrix with $upright("rank") \( X \) = r$ $ X = U D V^top \, $ where

- $U in bb(R)^(n times r)$, $U^top U = I$
- $D = "diag" \( d_1 \, dots.h \, d_r \)$, $d_1 gt.eq dots.h.c gt.eq d_r > 0$
- $V in bb(R)^(p times r)$, $V^top V = I$

#horizontalrule

=== Principal components (PC)
<principal-components-pc>
Principal component analysis (PCA) constructs new variables as linear combinations of the original predictors. It builds upon SVD.

Let \$Z =XV=UD= \\qty\[Z\_1, \\dots, Z\_r\]=\\mqty\[z\_{ij}\]\$ denote the principal components. Each principal component has the form $ Z_j = X v_j = v_(1 j) X_1 + v_(2 j) X_2 + dots.h + v_(p j) X_p $ where \$v\_j=\\mqty\[v\_{1j}&\\ldots&v\_{pj}\]^{\\top} \\in \\mathbb{R}^p\$ is a unit vector.

#strong[Loadings (directions)]

- Each PC is a linear combination of the columns of $X$.
- #strong[Loadings] ($v_(i j)$): The coefficients used to form PC $Z_j$ are called loadings.
- Loadings describe directions in feature space.

#strong[Scores (coordinates)]

- As a vector, each PC lies in $bb(R)^n$ (observation space).
- #strong[Scores] ($z_(i j)$): The coordinate of observation $i$ along direction $v_j$ is called the score.

Thus:

- rows of $Z$ = transformed observations,
- columns of $Z$ = principal components.

#example(title: [Centering and Scaling])[
~

Click to expand.
We use the same previous dataset #NormalTok("X");, centering it as #NormalTok("Xc"); and standarizing it as #NormalTok("Xs");.

#block[
#Skylighting(([#NormalTok("Xc ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("-");#NormalTok(" X.mean(axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[#NormalTok("Xs ");#OperatorTok("=");#NormalTok(" Xc ");#OperatorTok("/");#NormalTok(" Xc.std(axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],));
]
Now we plot them together with the princial compoenent. #NormalTok("pca()"); from #NormalTok("sklearn"); will automatically centering columns. In order to show the sceanario, we use #NormalTok("svd()"); from #NormalTok("numpy.linalg"); to do the computation.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[],
[#KeywordTok("def");#NormalTok(" pca_svd(X):");],
[#NormalTok("    U, D, Vt ");#OperatorTok("=");#NormalTok(" np.linalg.svd(X, full_matrices");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" Vt.T, D");],
[],
[],
[#KeywordTok("def");#NormalTok(" plot_svd(ax, X, V, title, scale");#OperatorTok("=");#DecValTok("3");#NormalTok(", length");#OperatorTok("=");#DecValTok("5");#NormalTok("):");],
[#NormalTok("    ax.scatter(X[:, ");#DecValTok("0");#NormalTok("], X[:, ");#DecValTok("1");#NormalTok("])");],
[#NormalTok("    t ");#OperatorTok("=");#NormalTok(" np.linspace(");#OperatorTok("-");#NormalTok("length, length, ");#DecValTok("100");#NormalTok(")");],
[#NormalTok("    line ");#OperatorTok("=");#NormalTok(" np.outer(t, V[:, ");#DecValTok("0");#NormalTok("])");],
[#NormalTok("    ax.plot(line[:, ");#DecValTok("0");#NormalTok("], line[:, ");#DecValTok("1");#NormalTok("], linewidth");#OperatorTok("=");#DecValTok("2");#NormalTok(", color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(")");],
[],
[#NormalTok("    ax.set_title(title)");],
[#NormalTok("    ax.set_xlabel(");#StringTok("\"x1\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#StringTok("\"x2\"");#NormalTok(")");],
[],
[],
[#NormalTok("V_raw ");#OperatorTok("=");#NormalTok(" np.linalg.svd(X, full_matrices");#OperatorTok("=");#VariableTok("False");#NormalTok(")[");#DecValTok("2");#NormalTok("].T");],
[#NormalTok("V_c ");#OperatorTok("=");#NormalTok(" np.linalg.svd(Xc, full_matrices");#OperatorTok("=");#VariableTok("False");#NormalTok(")[");#DecValTok("2");#NormalTok("].T");],
[#NormalTok("V_s ");#OperatorTok("=");#NormalTok(" np.linalg.svd(Xs, full_matrices");#OperatorTok("=");#VariableTok("False");#NormalTok(")[");#DecValTok("2");#NormalTok("].T");],
[],
[#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("15");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[],
[#NormalTok("plot_svd(axs[");#DecValTok("0");#NormalTok("], X, V_raw, ");#StringTok("\"Uncentered (Wrong PCA)\"");#NormalTok(")");],
[#NormalTok("plot_svd(axs[");#DecValTok("1");#NormalTok("], Xc, V_c, ");#StringTok("\"Centered\"");#NormalTok(")");],
[#NormalTok("plot_svd(axs[");#DecValTok("2");#NormalTok("], Xs, V_s, ");#StringTok("\"Centered + Scaled\"");#NormalTok(")");],
[],
[#NormalTok("plt.tight_layout()");],));
#box(image("contents\\1/dr_files/figure-typst/cell-4-output-1.svg"))

The principal component finds the direction that maximizes the variance of the projected data.

If the data are not centered, the optimization is no longer based purely on variance. In this case, the objective involves both the covariance structure and the mean of the data.

As a result, when the mean is large, the first principal direction may be strongly influenced by the location of the data, and can point roughly toward the data cloud rather than reflecting its intrinsic variation.

Note that the last two plots may appear similar at first glance. However, their coordinate scales are different, so this visual similarity can be misleading.

] <exm->

#horizontalrule

=== Covariance and Optimality
<covariance-and-optimality>
The sample covariance matrix is $S = frac(1, n - 1) X^top X$. By SVD, $ S = frac(1, n - 1) X^top X = V frac(D^2, n - 1) V^top $

- $V$: eigenvectors of covariance matrix \
- $d_j^2 \/ \( n - 1 \)$: eigenvalues of $S$
- $"Var" \( Z_j \) = d_j^2 \/ \( n - 1 \)$

Therefore

- First PC: Direction $v_1$ that maximizes $"Var" \( X v_1 \)$ subject to \$\\norm{v\_1}=1\$.
- Subsequent PCs: Maximize remaining variance subject to orthogonality (that they are orthogonal to all previous PCs $v_k^top v_j = 0$ for $j < k$).

#horizontalrule

=== Summary
<summary-1>
#table(
  columns: (24.39%, 19.51%, 17.07%, 39.02%),
  align: (auto,auto,auto,auto,),
  table.header([Component], [Matrix], [Space], [Interpretation],),
  table.hline(),
  [Loadings], [$V$], [Feature ($bb(R)^p$)], [Principal directions (rotation of axes)],
  [Scores], [$Z = U D$], [Observation ($bb(R)^n$)], [Transformed coordinates of observations],
  [Normalized scores], [$U$], [Observation ($bb(R)^n$)], [Directions of score vectors (unit length)],
  [Singular values], [$D$], [---], [Scaling of each component (spread)],
  [Variance], [$D^2 \/ \( n - 1 \)$], [---], [Importance of each principal component],
)
- Columns of $X$: variables in $bb(R)^n$ (relationships via angles)
- Rows of $X$: observations in $bb(R)^p$ (relationships via distance)
- PCA finds orthogonal directions in feature space
- $V$ gives directions, $Z$ gives coordinates
- SVD unifies everything: $ X = U D V^top \, quad Z = X V = U D $

#horizontalrule

=== Choosing the number of components ($m$)
<choosing-the-number-of-components-m>
Let \$\\rank(X)=r\$. PCA produces $r$ components, but in practice we keep only the first $m lt.eq r$.

Define the truncated SVD: $ X approx X_m = U_m D_m V_m^top \, $ where

- $U_m in bb(R)^(n times m)$
- $D_m in bb(R)^(m times m)$
- $V_m in bb(R)^(p times m)$

Correspondingly, $ Z_m = X V_m = U_m D_m $ contains the first $m$ principal components.

Keeping the $m$ largest singular values gives the best rank-$m$ approximation of $X$ in least squares sense.

==== Variance explained
<variance-explained>
The total variance is $ sum_(j = 1)^r frac(d_j^2, n - 1) \, $ and the proportion explained by the first $m$ components is $ frac(sum_(j = 1)^m d_j^2, sum_(j = 1)^r d_j^2) . $

==== Choosing $m$ for prediction (PCR)
<choosing-m-for-prediction-pcr>
In predictive settings, $m$ is typically selected via cross-validation:

+ Compute principal components.
+ Fit regression models using $m = 1 \, 2 \, dots.h \, r$ components.
+ Evaluate validation error.
+ Choose $m$ with the lowest validation error.

#block[
#callout(
body: 
[
The scree plot (elbow method) plots $d_j^2$ against $j$ and selects $m$ at the point where the marginal gain in variance explained drops sharply (the “elbow”). This identifies the number of components that captures most of the variation in $X$.

However, PCA is unsupervised: directions that explain high variance in $X$ do not necessarily have strong predictive power for $y$. Therefore, in predictive settings such as PCR, $m$ is typically chosen via cross-validation rather than the elbow method.

For unsupervised tasks (e.g., representation or clustering), the scree plot remains a reasonable and commonly used choice.

]
, 
title: 
[
Scree plot (Elbow method)
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== PCR in Python
<pcr-in-python>
=== PCA
<pca>
#NormalTok("scikit-learn"); provides #NormalTok("PCA"); for computing principal components. To demonstrate the code we use the same dataset from lasso.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("150");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("12");],
[],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, k))");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(k, p))");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" Z ");#OperatorTok("@");#NormalTok(" A ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, p))");],
[],
[#NormalTok("beta ");#OperatorTok("=");#NormalTok(" np.zeros(p)");],
[#NormalTok("beta[:");#DecValTok("10");#NormalTok("] ");#OperatorTok("=");#NormalTok(" [");#DecValTok("8");#NormalTok(", ");#DecValTok("7");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#FloatTok("0.5");#NormalTok("]");],
[],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("@");#NormalTok(" beta ");#OperatorTok("+");#NormalTok(" ");#DecValTok("12");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("n)");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");],
[#NormalTok(")");],));
]
#NormalTok("pca"); is an unsupervised learnning method. Therefore to perform it we only need #NormalTok("X");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.decomposition ");#ImportTok("import");#NormalTok(" PCA");],
[],
[#NormalTok("pca ");#OperatorTok("=");#NormalTok(" PCA().fit(X_train)");],));
]
All important information can be accessed from the returned object.

#block[
#Skylighting(([#NormalTok("V ");#OperatorTok("=");#NormalTok(" pca.components_.T                   ");#CommentTok("# loadings (V)");],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" pca.transform(X_train)              ");#CommentTok("# scores (Z)");],
[#NormalTok("D ");#OperatorTok("=");#NormalTok(" pca.singular_values_                ");#CommentTok("# singular values (D)");],
[#NormalTok("var ");#OperatorTok("=");#NormalTok(" pca.explained_variance_           ");#CommentTok("# variance that are explained");],
[#NormalTok("ratio ");#OperatorTok("=");#NormalTok(" pca.explained_variance_ratio_   ");#CommentTok("# the ratio of variance that are explained");],));
]
With #NormalTok("var"); and #NormalTok("ratio");, we may plot the scree plot (although we won't really use it to select the number of components).

#Skylighting(([#NormalTok("k ");#OperatorTok("=");#NormalTok(" np.arange(");#DecValTok("1");#NormalTok(", ");#BuiltInTok("len");#NormalTok("(var) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("plt.figure()");],
[#NormalTok("plt.plot(k, ratio, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"Component index\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Proportion of variance explained\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scree Plot (Variance Ratio)\"");#NormalTok(")");],
[],
[#NormalTok("cum ");#OperatorTok("=");#NormalTok(" np.cumsum(ratio)");],
[],
[#NormalTok("diff2 ");#OperatorTok("=");#NormalTok(" np.diff(cum, ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("elbow_idx ");#OperatorTok("=");#NormalTok(" np.argmin(diff2) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("elbow_k ");#OperatorTok("=");#NormalTok(" k[elbow_idx]");],
[#NormalTok("elbow_val ");#OperatorTok("=");#NormalTok(" ratio[elbow_idx]");],
[#NormalTok("plt.axvline(elbow_k, linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(")");],
[],
[#NormalTok("plt.scatter(elbow_k, elbow_val)");],
[#NormalTok("plt.text(elbow_k ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.2");#NormalTok(", elbow_val ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.004");#NormalTok(", ");#SpecialStringTok("f\"k=");#SpecialCharTok("{");#NormalTok("elbow_k");#SpecialCharTok("}");#CharTok("\\n");#SpecialCharTok("{");#NormalTok("elbow_val");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
/ Line 15: #block[
Use 2nd order difference to find the elbow.
]

]
#Skylighting(([#NormalTok("Text(13.2, 0.005666697882320329, 'k=13\\n0.002')");],));
#block[
#box(image("contents\\1/dr_files/figure-typst/cell-8-output-2.svg"))

]
=== PCR
<pcr>
Using PCA to do regression, we have to standarize the data. Therefore we set up the pipeline.

We first use 13 components (which comes from the scree plot) as our starting point. We will tune it later using cross-validation.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" Pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" mean_squared_error, r2_score");],
[],
[#NormalTok("pcr_pipe ");#OperatorTok("=");#NormalTok(" Pipeline(");],
[#NormalTok("    [");],
[#NormalTok("        (");#StringTok("\"scaler\"");#NormalTok(", StandardScaler()),");],
[#NormalTok("        (");#StringTok("\"pca\"");#NormalTok(", PCA(n_components");#OperatorTok("=");#DecValTok("13");#NormalTok(")),");],
[#NormalTok("        (");#StringTok("\"model\"");#NormalTok(", LinearRegression()),");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("pcr_pipe.fit(X_train, y_train)");],
[#NormalTok("y_pred_pcr ");#OperatorTok("=");#NormalTok(" pcr_pipe.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_pcr)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_pcr)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Test RMSE: 348.7698605548008");],
[#NormalTok("Test R^2 : 0.8536528530700276");],));
]
]
You may compare it with the results we get from #NormalTok("lasso"); and #NormalTok("ridge");.

=== Choosing number of components by cross-validation
<choosing-number-of-components-by-cross-validation>
We use $K$-fold cross validation to find the best number of components. Our criterion is negative MSE.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[],
[#NormalTok("n_splits ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("n_train_fold ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(X_train.shape[");#DecValTok("0");#NormalTok("] ");#OperatorTok("*");#NormalTok(" (n_splits ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#OperatorTok("/");#NormalTok(" n_splits)");],
[#NormalTok("max_components ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(n_train_fold, X_train.shape[");#DecValTok("1");#NormalTok("])");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");#StringTok("\"pca__n_components\"");#NormalTok(": ");#BuiltInTok("list");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", max_components ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("))}");],
[],
[#NormalTok("gs_pcr ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    pcr_pipe, param_grid, cv");#OperatorTok("=");#NormalTok("n_splits, scoring");#OperatorTok("=");#StringTok("\"neg_mean_squared_error\"");],
[#NormalTok(")");],
[#NormalTok("gs_pcr.fit(X_train, y_train)");],
[#NormalTok("gs_pcr.best_params_[");#StringTok("\"pca__n_components\"");#NormalTok("]");],));
#block[
/ Line 5: #block[
The maximal possible number of components depends on the shape of X. However for cross-validation, the number of rows of X is reduced due to the split. Therefore we have to estimate this number in order to avoid "#NormalTok("n_components"); out of bounds" warning.
]

]
#Skylighting(([#NormalTok("19");],));
It shows that 19 is the best number. Then we check the test result.

#block[
#Skylighting(([#NormalTok("y_pred_pcr ");#OperatorTok("=");#NormalTok(" gs_pcr.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_pcr)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_pcr)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Test RMSE: 321.0762521471908");],
[#NormalTok("Test R^2 : 0.8652733542572647");],));
]
]
It is slightly better than #NormalTok("13");, but still worse than tuned #NormalTok("ridge"); and #NormalTok("lasso");.

We could also look at the validation curve on the mean test score.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.plot(param_grid[");#StringTok("\"pca__n_components\"");#NormalTok("], gs_pcr.cv_results_[");#StringTok("\"mean_test_score\"");#NormalTok("])");],
[#NormalTok("plt.axvline(");#DecValTok("19");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best_gs\"");#NormalTok(")");],
[#NormalTok("plt.axvline(");#DecValTok("13");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", color");#OperatorTok("=");#StringTok("\"blue\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best_elbow\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\1/dr_files/figure-typst/cell-12-output-1.svg"))

== Partial Least Squares (PLS)
<partial-least-squares-pls>
One limitation of Principal Component Regression (PCR) is that it is unsupervised: the principal components depend only on $X$ and ignore the response $y$. As a result, directions with large variance in $X$ may not be relevant for predicting $y$.

Partial Least Squares (PLS) addresses this by constructing components that are guided by the response. It seeks directions in the predictor space that are both:

- informative about $X$, and
- strongly related to $y$

#definition(title: [Partial Least Squares])[
Partial least squares constructs a sequence of components

$ Z_k = X w_k $

where the weight vector $w_k$ is chosen to maximize the covariance between the component and the response: \$\$
w\_k =\\arg\\max\_{\\norm{w}=1}\\operatorname{Cov}(Xw, y).
\$\$

After constructing the component $Z_k$, both the predictor matrix $X$ and the response $y$ are deflated, and the procedure is repeated to construct additional components.

] <def-pls>
=== Algorithm intuition
<algorithm-intuition>
PLS constructs components sequentially, with each step explicitly targeting predictive power for $y$, rather than variance in $X$.

#strong[Step 1]: Find the direction. Choose a direction $w_k in bb(R)^p$ such that the component $Z_k = X_k w_k$ maximizes covariance with $y_k$. \$\$
w\_k =\\arg\\max\_{\\norm{w}=1}\\operatorname{Cov}(X\_kw, y\_k)
\$\$

#strong[Step 2]: Define the $k$-th component (also called the score vector): $ Z_k = X_k w_k in bb(R)^n $

- This is a linear combination of predictors
- Represents the direction in $X$ most aligned with $y_k$

#strong[Step 3]: Fit a simple regression of $y_k$ on $Z_k$: \$\$
y\_k=c\_kZ\_k+\\resid
\$\$ This captures how strongly the component explains $y_k$.

#strong[Step 4]: Deflation: remove the variation explained by $Z_k$ from both $X_k$ and $y_k$.

- Update response: $y_(k + 1) = y_k - c_k Z_k$
- Update predictors: $X_(k + 1) = X_k - Z_k p_k^top$, where $p_k = frac(X_k^top Z_k, Z_k^top Z_k)$.
  - $p_k$ are the loadings for reconstructing $X$
  - Deflation ensures the next components capture on new information

#strong[Step 5]: Repeat the process for $k = 1 \, 2 \, dots.h \, m$.

=== Key properties
<key-properties>
PLS has several important structural properties:

- The components ${ Z_1 \, Z_2 \, dots.h }$ are constructed sequentially. \
- Each component explains the remaining variation in $y$. \
- After deflation, the components are orthogonal. \
- The ordering reflects predictive importance.

At each step, the main quantities have distinct roles:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Quantity], [Interpretation],),
  table.hline(),
  [$w_k$], [Direction in feature space used to combine predictors],
  [$Z_k = X_k w_k$], [Score (component), representing projected data],
  [$p_k$], [Loading, describing how the component explains $X$],
)
Together, these quantities describe how information is extracted from $X$ and transferred to explain $y$.

=== Comparison with PCA
<comparison-with-pca>
The key difference between PCA and PLS lies in how the directions are chosen:

#table(
  columns: (8.96%, 53.73%, 37.31%),
  align: (auto,auto,auto,),
  table.header([Method], [Criterion], [Interpretation],),
  table.hline(),
  [PCA], [maximize $"Var" \( X w \)$], [captures structure of $X$],
  [PLS], [maximize $"Cov" \( X w \, y \)$], [targets prediction of $y$],
)
PCA captures the internal structure of $X$, while PLS focuses on directions that are useful for predicting $y$.

=== Geometric meaning (Krylov Subspace)
<geometric-meaning-krylov-subspace>
The matrix $X$ defines a cloud of points in $bb(R)^p$ and the response $y$ defines a direction in $bb(R)^n$.

PLS finds directions $w_k$ such that the projections $Z_k = X w_k$ are maximally aligned with $y$ in the observation space. In this sense, PLS can be understood geometrically as searching for directions in predictor space that align with the response.

To be more precise, it can be explained using Krylov subspaces.

Click to expand.
The Krylov subspace provides a structured way to generate directions for solving regression problems. Instead of searching the entire feature space $bb(R)^p$, it builds a sequence of low-dimensional subspaces that are tailored to the problem.

Given a matrix $A in bb(R)^(p times p)$ and a vector $b in bb(R)^p$, the Krylov subspace of order $k$ is defined as $ cal(K)_k \( A \, b \) = "span" { b \, #h(0em) A b \, #h(0em) A^2 b \, #h(0em) dots.h \, #h(0em) A^(k - 1) b } . $

The subspaces are nested, meaning $cal(K)_1 subset.eq cal(K)_2 subset.eq dots.h.c$, and the dimension cannot exceed \$\\rank(A)\$. Therefore, the sequence stabilizes after at most \$\\rank(A)\$ steps.

==== Krylov Subspace in Regression
<krylov-subspace-in-regression>
In linear regression, we take $ A = X^top X \, #h(2em) b = X^top y . $

Then the Krylov subspace becomes $ cal(K)_k \( X^top X \, X^top y \) = "span" { X^top y \, med \( X^top X \) X^top y \, med \( X^top X \)^2 X^top y \, dots.h } . $

The vector $X^top y$ represents directions in the predictor space that are most correlated with the response, while $X^top X$ encodes the covariance structure of the predictors. As a result, the Krylov subspace captures directions that are both aligned with $y$ and consistent with the geometry of $X$.

==== Connection to PLS
<connection-to-pls>
Partial Least Squares constructs its directions sequentially within the Krylov subspace: $ w_k in cal(K)_k \( X^top X \, #h(0em) X^top y \) . $

This means that PLS does not search over all possible directions in $bb(R)^p$. Instead, it expands a problem-dependent subspace step by step, starting from $X^top y$ and incorporating higher-order interactions through $X^top X$.

The number of components is therefore bounded by \$\$
m \\le \\dim(\\mathcal{K}\_k) \\le \\rank(X).
\$\$

#block[
#callout(
body: 
[
The Krylov subspace can be viewed as a guided search path inside $"span" \( X \)$. The first direction is determined by $X^top y$, and subsequent directions refine this information by incorporating the covariance structure of the predictors.

In this sense, the Krylov subspace represents the portion of the feature space that is relevant for predicting $y$. Methods such as PLS operate within this space, focusing on directions that carry predictive signal rather than exploring the entire feature space.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== PLS in Python
<pls-in-python>
Although the algorithm is different, the code is very similar to PCR. PLS is implemented by #NormalTok("PLSRegression"); from #NormalTok("sklearn.cross_decomposition");. The argument #NormalTok("scale=True"); is by default so we don't need to attach standardizer to it.

We choose the default number of componenets (which is 2) here. The specific hyperparameter will be tuned later by cross-validation.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.cross_decomposition ");#ImportTok("import");#NormalTok(" PLSRegression");],
[],
[#NormalTok("pls ");#OperatorTok("=");#NormalTok(" PLSRegression()");],
[],
[#NormalTok("pls.fit(X_train, y_train)");],));
]
We could use the following code to get access to the parameters.

#block[
#Skylighting(([#NormalTok("W ");#OperatorTok("=");#NormalTok(" pls.x_weights_    ");#CommentTok("# weights, directions (W)");],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" pls.x_scores_     ");#CommentTok("# scores, components (Z)");],
[#NormalTok("P ");#OperatorTok("=");#NormalTok(" pls.x_loadings_   ");#CommentTok("# loadings (P)");],));
]
=== Example
<example>
We use the same simulated dataset as before.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("150");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("k ");#OperatorTok("=");#NormalTok(" ");#DecValTok("12");],
[],
[#NormalTok("Z ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, k))");],
[#NormalTok("A ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(k, p))");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" Z ");#OperatorTok("@");#NormalTok(" A ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, p))");],
[],
[#NormalTok("beta ");#OperatorTok("=");#NormalTok(" np.zeros(p)");],
[#NormalTok("beta[:");#DecValTok("10");#NormalTok("] ");#OperatorTok("=");#NormalTok(" [");#DecValTok("8");#NormalTok(", ");#DecValTok("7");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#FloatTok("1.5");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#FloatTok("0.5");#NormalTok("]");],
[],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" X ");#OperatorTok("@");#NormalTok(" beta ");#OperatorTok("+");#NormalTok(" ");#DecValTok("12");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("n)");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");],
[#NormalTok(")");],));
]
Similar to PCR, we need to choose the number of components. Since PLS is fit inside cross-validation, the maximum number of components should be no larger than the number of observations in each training fold.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" sklearn.cross_decomposition ");#ImportTok("import");#NormalTok(" PLSRegression");],
[],
[#NormalTok("n_splits ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[#NormalTok("n_train_fold ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("int");#NormalTok("(X_train.shape[");#DecValTok("0");#NormalTok("] ");#OperatorTok("*");#NormalTok(" (n_splits ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#OperatorTok("/");#NormalTok(" n_splits)");],
[#NormalTok("max_components ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(n_train_fold, X_train.shape[");#DecValTok("1");#NormalTok("])");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");#StringTok("\"n_components\"");#NormalTok(": ");#BuiltInTok("list");#NormalTok("(");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", max_components ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("))}");],
[],
[#NormalTok("gs_pls ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    PLSRegression(), param_grid, cv");#OperatorTok("=");#NormalTok("n_splits, scoring");#OperatorTok("=");#StringTok("\"neg_mean_squared_error\"");],
[#NormalTok(")");],
[#NormalTok("gs_pls.fit(X_train, y_train)");],
[#NormalTok("gs_pls.best_params_[");#StringTok("\"n_components\"");#NormalTok("]");],));
#Skylighting(([#NormalTok("4");],));
After selecting the number of components by cross-validation, we evaluate the fitted model on the test set.

#block[
#Skylighting(([#NormalTok("y_pred_pls ");#OperatorTok("=");#NormalTok(" gs_pls.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test RMSE: ");#SpecialCharTok("{");#NormalTok("mean_squared_error(y_test, y_pred_pls)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Test R^2 : ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_pls)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Test RMSE: 333.9484272722302");],
[#NormalTok("Test R^2 : 0.8598720672844287");],));
]
]
The validation curve shows how the cross-validation error changes as the number of PLS components increases.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.plot(param_grid[");#StringTok("\"n_components\"");#NormalTok("], gs_pls.cv_results_[");#StringTok("\"mean_test_score\"");#NormalTok("])");],
[#NormalTok("plt.axvline(");],
[#NormalTok("    gs_pls.best_params_[");#StringTok("\"n_components\"");#NormalTok("],");],
[#NormalTok("    linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(",");],
[#NormalTok("    color");#OperatorTok("=");#StringTok("\"red\"");#NormalTok(",");],
[#NormalTok("    label");#OperatorTok("=");#StringTok("\"best_gs\"");#NormalTok(",");],
[#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\1/dr_files/figure-typst/cell-18-output-1.svg"))

#block[
#callout(
body: 
[
- #NormalTok("PLSRegression"); automatically centers and scales the predictors by default.
- Unlike PCR, PLS uses both $X$ and $y$ when constructing components.
- The number of components should be chosen by cross-validation.
- Very large numbers of components are usually unnecessary and may lead to numerical warnings.

]
, 
title: 
[
Important Notes
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
The results for this dataset are summarized in the following table.

#block[
#block[
#Skylighting(([#NormalTok("<>:90: SyntaxWarning: \"is not\" with 'str' literal. Did you mean \"!=\"?");],
[#NormalTok("<>:90: SyntaxWarning: \"is not\" with 'str' literal. Did you mean \"!=\"?");],
[#NormalTok("C:\\Users\\xiaox\\AppData\\Local\\Temp\\ipykernel_31188\\4187596780.py:90: SyntaxWarning: \"is not\" with 'str' literal. Did you mean \"!=\"?");],
[#NormalTok("  if (ols_in is True) or ((ols_in is False) and (name is not \"OLS\")):");],));
]
]
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[Test RMSE], table.cell(align: right)[Test R²], table.cell(align: right)[Best param],
    table.cell(align: right)[Model], table.cell(align: right)[], table.cell(align: right)[], table.cell(align: right)[],),
  table.hline(),
  table.cell(align: horizon)[OLS], [1212.5155], [0.491217], [NaN],
  table.cell(align: horizon)[RidgeCV], [274.2522], [0.884921], [alpha=10.0],
  table.cell(align: horizon)[LassoCV], [221.7648], [0.906945], [alpha=0.4608014833934263],
  table.cell(align: horizon)[PCR], [321.0763], [0.865273], [n\_components=19],
  table.cell(align: horizon)[PLS], [333.9484], [0.859872], [n\_components=4],
)
Note that PCR and PLS do not perform as well as ridge and lasso in this example. A key reason lies in how the dataset is generated.

- The coefficient vector $beta$ is sparse: only a small number of predictors (10 out of 100) are truly relevant.
- The noise level is relatively high, making signal recovery more difficult.
- More importantly, the variation in $X$ is driven by a low-dimensional latent structure ($Z A$), while the true signal depends on a sparse set of original predictors. As a result, the directions of largest variance in $X$ are not necessarily aligned with the directions that predict $y$.

Since PCR relies only on variance in $X$, and PLS is still influenced by this structure, both methods may fail to recover the true signal efficiently. In contrast, ridge and lasso operate directly on the original predictors, with lasso particularly well-suited for identifying sparse signals.

=== Another example
<another-example>
Now let us look at another example. In this setting, we construct $X$ so that most of its variance comes from irrelevant noise, while the true signal has low variance but determines $y$. Specifically, $ y = Z_1 b + epsilon_Y \, quad X = Z_1 A_1 + Z_2 A_2 + epsilon_X . $

This setup has the following properties:

- $Z_1$ (signal) has low variance, while $Z_2$ (noise) has high variance.
- $y$ depends only on $Z_1$.
- Therefore, the predictive signal lies in low-variance but structured (low-rank) directions of $X$.
- For simplicity, we take $Z_1$ to be one-dimensional in the following example.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("42");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("120");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("300");],
[],
[#NormalTok("Z_1 ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, ");#DecValTok("1");#NormalTok("))");],
[#NormalTok("A_1 ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(");#DecValTok("1");#NormalTok(", p))");],
[#NormalTok("X_signal ");#OperatorTok("=");#NormalTok(" Z_1 ");#OperatorTok("@");#NormalTok(" A_1 ");#OperatorTok("*");#NormalTok(" ");#FloatTok("0.15");],
[],
[#NormalTok("k_2 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("Z_2 ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, k_2))");],
[#NormalTok("A_2 ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(k_2, p))");],
[#NormalTok("X_noise ");#OperatorTok("=");#NormalTok(" Z_2 ");#OperatorTok("@");#NormalTok(" A_2 ");#OperatorTok("*");#NormalTok(" ");#DecValTok("15");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" X_noise ");#OperatorTok("+");#NormalTok(" X_signal ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, p))");],
[],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("12");#NormalTok(" ");#OperatorTok("*");#NormalTok(" Z_1.ravel() ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("n)");],));
]
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[Test RMSE], table.cell(align: right)[Test R²], table.cell(align: right)[Best param],
    table.cell(align: right)[Model], table.cell(align: right)[], table.cell(align: right)[], table.cell(align: right)[],),
  table.hline(),
  table.cell(align: horizon)[RidgeCV], [34.7296], [0.682587], [alpha=0.1],
  table.cell(align: horizon)[LassoCV], [22.8245], [0.791395], [alpha=0.0022916910232695206],
  table.cell(align: horizon)[PCR], [17.2454], [0.842385], [n\_components=51],
  table.cell(align: horizon)[PLS], [16.2460], [0.851518], [n\_components=12],
)
In this example, PCR and especially PLS tend to outperform ridge and lasso.

- PCR can recover the signal if enough components are included, even though the signal lies in low-variance directions.
- PLS performs particularly well because it uses $y$ when constructing components, allowing it to directly identify directions associated with the response.
- Ridge and lasso shrink coefficients based on the observed predictors. Since the signal is weak (low variance) and spread across many features through $A_1$, it is harder for them to isolate and recover it.

#block[
#callout(
body: 
[
Important predictive directions do not have to correspond to directions of large variance.

]
, 
title: 
[
Caution
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
= Logistic Regression
<logistic-regression>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
Logistic regression is a classification method for binary outcomes. It models the conditional probability of the positive class as a function of the predictors.

For a binary response, write

$ Y in { 0 \, 1 } . $

The main target is the conditional probability

$ p \( x \) = Pr \( Y = 1 divides X = x \) . $

Once this probability is estimated, it can be used for several related tasks:

- probability estimation;
- ranking observations by risk;
- hard classification after choosing a threshold.

#block[
#callout(
body: 
[
Logistic regression estimates probabilities. A classification threshold then converts those probabilities into decisions.

These are related, but they are not the same problem.

]
, 
title: 
[
Model and decision
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Modeling Binary Outcomes
<modeling-binary-outcomes>
In linear regression, we model a quantitative response by

$ Y = beta_0 + beta_1 x_1 + dots.h.c + beta_p x_p + epsilon . $

This is not appropriate for a binary response if the fitted value is interpreted as a probability. A linear function can be below 0 or above 1.

Logistic regression solves this problem by modeling the probability through the logistic function.

Let

$ eta \( x \) = beta_0 + beta_1 x_1 + dots.h.c + beta_p x_p = x^top beta \, $

where $x^top beta$ includes the intercept term if the first component of $x$ is 1. Logistic regression defines

$ p \( x \) = Pr \( Y = 1 divides X = x \) = frac(exp \( eta \( x \) \), 1 + exp \( eta \( x \) \)) = frac(1, 1 + exp \( - eta \( x \) \)) . $

This guarantees

$ 0 < p \( x \) < 1 . $

The inverse transformation is the logit function:

$ log (frac(p \( x \), 1 - p \( x \))) = eta \( x \) = x^top beta . $

#block[
#callout(
body: 
[
Logistic regression is linear in the log-odds, not linear in the probability.

]
, 
title: 
[
Main idea
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Odds and Coefficient Interpretation
<odds-and-coefficient-interpretation>
The odds of class 1 are

$ frac(p \( x \), 1 - p \( x \)) . $

Since

$ log (frac(p \( x \), 1 - p \( x \))) = beta_0 + beta_1 x_1 + dots.h.c + beta_p x_p \, $

a one-unit increase in $x_j$, holding all other predictors fixed, changes the log-odds by

$ beta_j . $

Exponentiating gives the odds ratio:

$ upright("new odds") / upright("old odds") = exp \( beta_j \) . $

Thus:

- $beta_j$ is the change in log-odds for a one-unit increase in $x_j$\;
- $exp \( beta_j \)$ is the multiplicative change in the odds.

#block[
#callout(
body: 
[
A logistic regression coefficient is not a direct change in probability. The probability change depends on the current value of all predictors.

]
, 
title: 
[
Not a probability change
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
For example, if $beta_j = 0.05$, then

$ e^0.05 approx 1.051 . $

Holding other predictors fixed, a one-unit increase in $x_j$ multiplies the odds by about $1.051$, or increases the odds by about $5.1 %$.

== A One-Variable Calculation
<a-one-variable-calculation>
Suppose the fitted model is

$ log (frac(p \( x \), 1 - p \( x \))) = - 3.006 + 0.052 x . $

For a subject with $x = 55$,

$ eta \( 55 \) = - 3.006 + 0.052 \( 55 \) = - 0.146 . $

The estimated probability is

$ hat(p) \( 55 \) = frac(e^(- 0.146), 1 + e^(- 0.146)) approx 0.463 . $

So the model estimates a class-1 probability of about $46.3 %$.

== Estimation by Maximum Likelihood
<estimation-by-maximum-likelihood>
For observation $i$, let

$ p_i = p \( x_i \) = Pr \( Y_i = 1 divides X_i = x_i \) . $

The binary response model is

$ Y_i divides X_i = x_i tilde.op "Bernoulli" \( p_i \) . $

Therefore

$ Pr \( Y_i = y_i divides X_i = x_i \) = p_i^(y_i) \( 1 - p_i \)^(1 - y_i) . $

For independent observations, the likelihood is

$ L \( beta \) = product_(i = 1)^n p_i^(y_i) \( 1 - p_i \)^(1 - y_i) . $

The log-likelihood is

$ ell \( beta \) = sum_(i = 1)^n [y_i log \( p_i \) + \( 1 - y_i \) log \( 1 - p_i \)] . $

Using

$ p_i = frac(exp \( x_i^top beta \), 1 + exp \( x_i^top beta \)) \, $

the log-likelihood can also be written as

$ ell \( beta \) = sum_(i = 1)^n [y_i x_i^top beta - log { 1 + exp \( x_i^top beta \) }] . $

The negative average log-likelihood is the binary cross-entropy loss:

$ - 1 / n ell \( beta \) = - 1 / n sum_(i = 1)^n [y_i log \( p_i \) + \( 1 - y_i \) log \( 1 - p_i \)] . $

Logistic regression chooses

$ hat(beta) = arg max_beta ell \( beta \) = arg min_beta { - ell \( beta \) } . $

Unlike ordinary least squares, logistic regression does not have a closed-form solution. The coefficients are found by numerical optimization.

The score vector is

$ nabla_beta ell \( beta \) = X^top \( y - p \) \, $

where $p = \( p_1 \, dots.h \, p_n \)^top$. The Hessian is

$ nabla_beta^2 ell \( beta \) = - X^top W X \, $

where

$ W = "diag" { p_i \( 1 - p_i \) } . $

Since the Hessian is negative semidefinite, the log-likelihood is concave in $beta$. This is why Newton-type algorithms and iteratively reweighted least squares are natural fitting methods for logistic regression.

== Deviance
<deviance>
In logistic regression and other generalized linear models, deviance measures lack of fit relative to a saturated model.

For a fitted logistic regression model, the residual deviance is

$ D = - 2 ell \( hat(beta) \) + 2 ell_(upright("saturated")) . $

For Bernoulli data, the saturated model fits each observation perfectly, so the saturated log-likelihood is 0. Therefore the residual deviance is often written as

$ D = - 2 ell \( hat(beta) \) . $

Two common quantities are:

- null deviance: deviance for an intercept-only model;
- residual deviance: deviance for the fitted model.

A large reduction from null deviance to residual deviance means the predictors explain useful information about the class probabilities.

== From Probabilities to Decisions
<from-probabilities-to-decisions>
After fitting the model, the estimated probability is

$ hat(p) \( x \) = hat(Pr) \( Y = 1 divides X = x \) . $

A hard classification requires a threshold $c$:

$ hat(Y) = cases(delim: "{", 1 \, & hat(p) \( x \) > c \,, 0 \, & hat(p) \( x \) lt.eq c .) $

The default threshold is often $c = 0.5$, but this is not always the best choice. Changing the threshold changes the confusion matrix and therefore changes accuracy, precision, recall, false positive rate, and F1 score.

Suppose a false positive has cost $C_(F P)$ and a false negative has cost $C_(F N)$. If $hat(p) \( x \)$ is a calibrated estimate of $p \( x \)$, then the expected cost of predicting positive is

$ upright("Cost") \( 1 divides x \) = C_(F P) { 1 - p \( x \) } \, $

and the expected cost of predicting negative is

$ upright("Cost") \( 0 divides x \) = C_(F N) p \( x \) . $

Predict positive when

$ C_(F P) { 1 - p \( x \) } < C_(F N) p \( x \) . $

Solving gives the decision-theoretic threshold

$ c^(*) = frac(C_(F P), C_(F P) + C_(F N)) . $

If false negatives are more costly, then $C_(F N)$ is large and the threshold becomes smaller. The classifier predicts the positive class more aggressively.

#block[
#callout(
body: 
[
Threshold tuning changes the decision rule built on top of $hat(p) \( x \)$. It does not refit the logistic regression model or change the fitted probabilities.

]
, 
title: 
[
Threshold tuning
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Logistic Regression in #NormalTok("sklearn");
<logistic-regression-in-sklearn>
#NormalTok("sklearn"); is usually the better choice for predictive workflows, train-test splits, pipelines, cross-validation, and threshold tuning.

We use a pipeline with standardization. Scaling is especially important for penalized logistic regression, because the penalty is applied to coefficients.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[],
[#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_breast_cancer");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[#ImportTok("from");#NormalTok(" sklearn.pipeline ");#ImportTok("import");#NormalTok(" make_pipeline");],
[#ImportTok("from");#NormalTok(" sklearn.preprocessing ");#ImportTok("import");#NormalTok(" StandardScaler");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LogisticRegression");],
[],
[#NormalTok("cancer ");#OperatorTok("=");#NormalTok(" load_breast_cancer(as_frame");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" cancer.data[[");#StringTok("\"mean radius\"");#NormalTok(", ");#StringTok("\"mean texture\"");#NormalTok(", ");#StringTok("\"mean concavity\"");#NormalTok("]]");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" cancer.target");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X,");],
[#NormalTok("    y,");],
[#NormalTok("    test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(",");],
[#NormalTok("    stratify");#OperatorTok("=");#NormalTok("y,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("logit ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LogisticRegression(penalty");#OperatorTok("=");#VariableTok("None");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok(")");],
[],
[#NormalTok("logit.fit(X_train, y_train)");],
[],
[#NormalTok("test_prob ");#OperatorTok("=");#NormalTok(" logit.predict_proba(X_test)[:, ");#DecValTok("1");#NormalTok("]");],
[#NormalTok("test_pred ");#OperatorTok("=");#NormalTok(" logit.predict(X_test)");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],));
]
]
#NormalTok("predict"); returns class labels. #NormalTok("predict_proba"); returns estimated class probabilities.

#Skylighting(([#NormalTok("logit.predict_proba(X_test[:");#DecValTok("5");#NormalTok("])");],));
#Skylighting(([#NormalTok("array([[9.97324773e-01, 2.67522723e-03],");],
[#NormalTok("       [6.19687503e-01, 3.80312497e-01],");],
[#NormalTok("       [1.58637887e-06, 9.99998414e-01],");],
[#NormalTok("       [9.99826965e-01, 1.73035413e-04],");],
[#NormalTok("       [9.99753274e-01, 2.46725763e-04]])");],));
The second column is the estimated probability of the positive class, which is malignant in this example.

#block[
#callout(
body: 
[
#NormalTok("sklearn.linear_model.LogisticRegression"); uses regularization by default. Use #NormalTok("penalty=None"); for an unpenalized logistic regression.

]
, 
title: 
[
Regularization default
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
== Confusion Matrix and Basic Metrics
<confusion-matrix-and-basic-metrics-1>
Threshold-based metrics compare true labels with predicted labels.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" (");],
[#NormalTok("    confusion_matrix,");],
[#NormalTok("    accuracy_score,");],
[#NormalTok("    precision_score,");],
[#NormalTok("    recall_score,");],
[#NormalTok("    f1_score,");],
[#NormalTok(")");],
[],
[#NormalTok("confusion_matrix(y_test, test_pred)");],));
#Skylighting(([#NormalTok("array([[104,   3],");],
[#NormalTok("       [ 12,  52]])");],));
Since class 0 is negative and class 1 is positive, the entries are ordered as

$ mat(delim: "(", T N, F P; F N, T P) . $

We can extract the four entries and compute common metrics.

#Skylighting(([#NormalTok("TN, FP, FN, TP ");#OperatorTok("=");#NormalTok(" confusion_matrix(y_test, test_pred).ravel()");],
[],
[#NormalTok("basic_metrics ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"accuracy\"");#NormalTok(": accuracy_score(y_test, test_pred),");],
[#NormalTok("    ");#StringTok("\"precision\"");#NormalTok(": precision_score(y_test, test_pred),");],
[#NormalTok("    ");#StringTok("\"recall\"");#NormalTok(": recall_score(y_test, test_pred),");],
[#NormalTok("    ");#StringTok("\"f1\"");#NormalTok(": f1_score(y_test, test_pred),");],
[#NormalTok("}");],
[],
[#NormalTok("basic_metrics");],));
#Skylighting(([#NormalTok("{'accuracy': 0.9122807017543859,");],
[#NormalTok(" 'precision': 0.9454545454545454,");],
[#NormalTok(" 'recall': 0.8125,");],
[#NormalTok(" 'f1': 0.8739495798319328}");],));
== Changing the Classification Threshold
<changing-the-classification-threshold>
The default threshold used by #NormalTok("predict()"); is $0.5$ for binary logistic regression. To use a different threshold, work directly with the estimated probabilities.

There are three common ways to choose a threshold:

- choose it manually based on the desired precision-recall tradeoff;
- tune it on validation data or by cross-validation for a target metric;
- derive it from an explicit cost function when error costs are known.

#Skylighting(([#NormalTok("threshold ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.3");],
[#NormalTok("pred_03 ");#OperatorTok("=");#NormalTok(" (test_prob ");#OperatorTok(">=");#NormalTok(" threshold).astype(");#BuiltInTok("int");#NormalTok(")");],
[],
[#NormalTok("confusion_matrix(y_test, pred_03)");],));
#Skylighting(([#NormalTok("array([[102,   5],");],
[#NormalTok("       [  7,  57]])");],));
A small helper function makes it easier to compare thresholds.

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" classification_summary(y_true, prob, threshold");#OperatorTok("=");#FloatTok("0.5");#NormalTok("):");],
[#NormalTok("    pred ");#OperatorTok("=");#NormalTok(" (prob ");#OperatorTok(">=");#NormalTok(" threshold).astype(");#BuiltInTok("int");#NormalTok(")");],
[#NormalTok("    TN, FP, FN, TP ");#OperatorTok("=");#NormalTok(" confusion_matrix(y_true, pred).ravel()");],
[],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" {");],
[#NormalTok("        ");#StringTok("\"threshold\"");#NormalTok(": threshold,");],
[#NormalTok("        ");#StringTok("\"TP\"");#NormalTok(": TP,");],
[#NormalTok("        ");#StringTok("\"FP\"");#NormalTok(": FP,");],
[#NormalTok("        ");#StringTok("\"FN\"");#NormalTok(": FN,");],
[#NormalTok("        ");#StringTok("\"TN\"");#NormalTok(": TN,");],
[#NormalTok("        ");#StringTok("\"accuracy\"");#NormalTok(": accuracy_score(y_true, pred),");],
[#NormalTok("        ");#StringTok("\"precision\"");#NormalTok(": precision_score(y_true, pred, zero_division");#OperatorTok("=");#DecValTok("0");#NormalTok("),");],
[#NormalTok("        ");#StringTok("\"recall\"");#NormalTok(": recall_score(y_true, pred, zero_division");#OperatorTok("=");#DecValTok("0");#NormalTok("),");],
[#NormalTok("        ");#StringTok("\"f1\"");#NormalTok(": f1_score(y_true, pred, zero_division");#OperatorTok("=");#DecValTok("0");#NormalTok("),");],
[#NormalTok("    }");],));
]
For illustration, first examine a grid of thresholds on the current evaluation data. In a real analysis, the threshold should be selected on validation data or through cross-validation, not on the final test set.

#Skylighting(([#NormalTok("thresholds ");#OperatorTok("=");#NormalTok(" np.linspace(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.95");#NormalTok(", ");#DecValTok("19");#NormalTok(")");],
[],
[#NormalTok("threshold_df ");#OperatorTok("=");#NormalTok(" pd.DataFrame(");],
[#NormalTok("    [");],
[#NormalTok("        classification_summary(y_test, test_prob, threshold");#OperatorTok("=");#NormalTok("t)");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" t ");#KeywordTok("in");#NormalTok(" thresholds");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("threshold_df.head()");],));
#table(
  columns: 10,
  align: (auto,auto,auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[threshold], table.cell(align: right)[TP], table.cell(align: right)[FP], table.cell(align: right)[FN], table.cell(align: right)[TN], table.cell(align: right)[accuracy], table.cell(align: right)[precision], table.cell(align: right)[recall], table.cell(align: right)[f1],),
  table.hline(),
  table.cell(align: horizon)[0], [0.05], [62], [22], [2], [85], [0.859649], [0.738095], [0.968750], [0.837838],
  table.cell(align: horizon)[1], [0.10], [59], [13], [5], [94], [0.894737], [0.819444], [0.921875], [0.867647],
  table.cell(align: horizon)[2], [0.15], [58], [8], [6], [99], [0.918129], [0.878788], [0.906250], [0.892308],
  table.cell(align: horizon)[3], [0.20], [57], [6], [7], [101], [0.923977], [0.904762], [0.890625], [0.897638],
  table.cell(align: horizon)[4], [0.25], [57], [5], [7], [102], [0.929825], [0.919355], [0.890625], [0.904762],
)
Plot precision and recall as functions of the threshold.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.plot(threshold_df[");#StringTok("\"threshold\"");#NormalTok("], threshold_df[");#StringTok("\"precision\"");#NormalTok("], marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"precision\"");#NormalTok(")");],
[#NormalTok("plt.plot(threshold_df[");#StringTok("\"threshold\"");#NormalTok("], threshold_df[");#StringTok("\"recall\"");#NormalTok("], marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"recall\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"threshold\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"metric value\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Precision and Recall versus Threshold\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\1/logistic_files/figure-typst/cell-9-output-1.svg"))

As the threshold increases, the classifier becomes more conservative in predicting the positive class. This often reduces false positives and increases precision, but it may also increase false negatives and reduce recall.

=== Selecting a Threshold on Validation Data
<selecting-a-threshold-on-validation-data>
The threshold should not be selected using the final test set. A common workflow is:

+ split the available training data into a model-training set and a validation set;
+ fit the logistic regression model on the model-training set;
+ evaluate candidate thresholds on the validation set;
+ refit the model on the full training set if desired;
+ evaluate once on the test set.

The following example chooses the threshold that maximizes validation F1 score.

#Skylighting(([#NormalTok("X_model, X_valid, y_model, y_valid ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X_train,");],
[#NormalTok("    y_train,");],
[#NormalTok("    test_size");#OperatorTok("=");#FloatTok("0.25");#NormalTok(",");],
[#NormalTok("    stratify");#OperatorTok("=");#NormalTok("y_train,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("11");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("validation_model ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LogisticRegression(penalty");#OperatorTok("=");#VariableTok("None");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok(")");],
[],
[#NormalTok("validation_model.fit(X_model, y_model)");],
[#NormalTok("valid_prob ");#OperatorTok("=");#NormalTok(" validation_model.predict_proba(X_valid)[:, ");#DecValTok("1");#NormalTok("]");],
[],
[#NormalTok("candidate_thresholds ");#OperatorTok("=");#NormalTok(" np.linspace(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.95");#NormalTok(", ");#DecValTok("91");#NormalTok(")");],
[],
[#NormalTok("validation_results ");#OperatorTok("=");#NormalTok(" pd.DataFrame(");],
[#NormalTok("    [");],
[#NormalTok("        classification_summary(y_valid, valid_prob, threshold");#OperatorTok("=");#NormalTok("t)");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" t ");#KeywordTok("in");#NormalTok(" candidate_thresholds");],
[#NormalTok("    ]");],
[#NormalTok(")");],
[],
[#NormalTok("best_f1_row ");#OperatorTok("=");#NormalTok(" validation_results.loc[");],
[#NormalTok("    validation_results[");#StringTok("\"f1\"");#NormalTok("].idxmax()");],
[#NormalTok("]");],
[],
[#NormalTok("best_f1_row");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],));
]
#Skylighting(([#NormalTok("threshold     0.700000");],
[#NormalTok("TP           32.000000");],
[#NormalTok("FP            0.000000");],
[#NormalTok("FN            5.000000");],
[#NormalTok("TN           63.000000");],
[#NormalTok("accuracy      0.950000");],
[#NormalTok("precision     1.000000");],
[#NormalTok("recall        0.864865");],
[#NormalTok("f1            0.927536");],
[#NormalTok("Name: 65, dtype: float64");],));
The selected threshold can then be applied to the test probabilities from the original fitted model.

#Skylighting(([#NormalTok("best_threshold ");#OperatorTok("=");#NormalTok(" best_f1_row[");#StringTok("\"threshold\"");#NormalTok("]");],
[],
[#NormalTok("classification_summary(");],
[#NormalTok("    y_test,");],
[#NormalTok("    test_prob,");],
[#NormalTok("    threshold");#OperatorTok("=");#NormalTok("best_threshold,");],
[#NormalTok(")");],));
#Skylighting(([#NormalTok("{'threshold': np.float64(0.7),");],
[#NormalTok(" 'TP': np.int64(49),");],
[#NormalTok(" 'FP': np.int64(2),");],
[#NormalTok(" 'FN': np.int64(15),");],
[#NormalTok(" 'TN': np.int64(105),");],
[#NormalTok(" 'accuracy': 0.9005847953216374,");],
[#NormalTok(" 'precision': 0.9607843137254902,");],
[#NormalTok(" 'recall': 0.765625,");],
[#NormalTok(" 'f1': 0.8521739130434782}");],));
The same idea can be used for other goals. For example, we may want the largest recall among thresholds whose precision is at least $0.90$.

#Skylighting(([#NormalTok("valid_candidates ");#OperatorTok("=");#NormalTok(" validation_results[");],
[#NormalTok("    validation_results[");#StringTok("\"precision\"");#NormalTok("] ");#OperatorTok(">=");#NormalTok(" ");#FloatTok("0.90");],
[#NormalTok("]");],
[],
[#NormalTok("best_recall_row ");#OperatorTok("=");#NormalTok(" valid_candidates.loc[");],
[#NormalTok("    valid_candidates[");#StringTok("\"recall\"");#NormalTok("].idxmax()");],
[#NormalTok("]");],
[],
[#NormalTok("best_recall_row");],));
#Skylighting(([#NormalTok("threshold     0.570000");],
[#NormalTok("TP           33.000000");],
[#NormalTok("FP            3.000000");],
[#NormalTok("FN            4.000000");],
[#NormalTok("TN           60.000000");],
[#NormalTok("accuracy      0.930000");],
[#NormalTok("precision     0.916667");],
[#NormalTok("recall        0.891892");],
[#NormalTok("f1            0.904110");],
[#NormalTok("Name: 52, dtype: float64");],));
#Skylighting(([#NormalTok("classification_summary(");],
[#NormalTok("    y_test,");],
[#NormalTok("    test_prob,");],
[#NormalTok("    threshold");#OperatorTok("=");#NormalTok("best_recall_row[");#StringTok("\"threshold\"");#NormalTok("],");],
[#NormalTok(")");],));
#Skylighting(([#NormalTok("{'threshold': np.float64(0.57),");],
[#NormalTok(" 'TP': np.int64(51),");],
[#NormalTok(" 'FP': np.int64(3),");],
[#NormalTok(" 'FN': np.int64(13),");],
[#NormalTok(" 'TN': np.int64(104),");],
[#NormalTok(" 'accuracy': 0.9064327485380117,");],
[#NormalTok(" 'precision': 0.9444444444444444,");],
[#NormalTok(" 'recall': 0.796875,");],
[#NormalTok(" 'f1': 0.864406779661017}");],));
== Fixed and Tuned Thresholds in #NormalTok("sklearn");
<fixed-and-tuned-thresholds-in-sklearn>
Manual thresholding is often the clearest method. #NormalTok("sklearn"); also provides wrappers that make the threshold part of the estimator workflow.

If the threshold is fixed in advance, use #NormalTok("FixedThresholdClassifier");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" FixedThresholdClassifier");],
[],
[#NormalTok("fixed_threshold_model ");#OperatorTok("=");#NormalTok(" FixedThresholdClassifier(");],
[#NormalTok("    make_pipeline(");],
[#NormalTok("        StandardScaler(),");],
[#NormalTok("        LogisticRegression(penalty");#OperatorTok("=");#VariableTok("None");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok("    ),");],
[#NormalTok("    threshold");#OperatorTok("=");#FloatTok("0.3");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("fixed_threshold_model.fit(X_train, y_train)");],
[#NormalTok("fixed_pred ");#OperatorTok("=");#NormalTok(" fixed_threshold_model.predict(X_test)");],
[],
[#NormalTok("confusion_matrix(y_test, fixed_pred)");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],));
]
#Skylighting(([#NormalTok("array([[102,   5],");],
[#NormalTok("       [  7,  57]])");],));
If the threshold should be selected from data, use #NormalTok("TunedThresholdClassifierCV");. This performs cross-validation to choose a threshold for a specified scoring criterion.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" TunedThresholdClassifierCV");],
[],
[#NormalTok("tuned_threshold_model ");#OperatorTok("=");#NormalTok(" TunedThresholdClassifierCV(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("make_pipeline(");],
[#NormalTok("        StandardScaler(),");],
[#NormalTok("        LogisticRegression(penalty");#OperatorTok("=");#VariableTok("None");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok("    ),");],
[#NormalTok("    scoring");#OperatorTok("=");#StringTok("\"recall\"");#NormalTok(",");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("tuned_threshold_model.fit(X_train, y_train)");],
[#NormalTok("tuned_pred ");#OperatorTok("=");#NormalTok(" tuned_threshold_model.predict(X_test)");],
[],
[#NormalTok("{");],
[#NormalTok("    ");#StringTok("\"accuracy\"");#NormalTok(": accuracy_score(y_test, tuned_pred),");],
[#NormalTok("    ");#StringTok("\"precision\"");#NormalTok(": precision_score(y_test, tuned_pred),");],
[#NormalTok("    ");#StringTok("\"recall\"");#NormalTok(": recall_score(y_test, tuned_pred),");],
[#NormalTok("    ");#StringTok("\"f1\"");#NormalTok(": f1_score(y_test, tuned_pred),");],
[#NormalTok("}");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],));
]
#Skylighting(([#NormalTok("{'accuracy': 0.3742690058479532,");],
[#NormalTok(" 'precision': 0.3742690058479532,");],
[#NormalTok(" 'recall': 1.0,");],
[#NormalTok(" 'f1': 0.5446808510638298}");],));
#block[
#callout(
body: 
[
The threshold should be chosen using training data or validation data, not the final test set. The test set should be used only for the final evaluation.

]
, 
title: 
[
Tune thresholds on training data only
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
== Choosing a Threshold from Costs
<choosing-a-threshold-from-costs-1>
In a medical screening setting, missing a malignant tumor may be more costly than sending a benign case for additional testing. Suppose

$ C_(F N) = 5 \, #h(2em) C_(F P) = 1 . $

The cost-based threshold is

$ c^(*) = frac(C_(F P), C_(F P) + C_(F N)) = frac(1, 1 + 5) approx 0.167 . $

#Skylighting(([#NormalTok("cost_fp ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("cost_fn ");#OperatorTok("=");#NormalTok(" ");#DecValTok("5");],
[],
[#NormalTok("cost_threshold ");#OperatorTok("=");#NormalTok(" cost_fp ");#OperatorTok("/");#NormalTok(" (cost_fp ");#OperatorTok("+");#NormalTok(" cost_fn)");],
[],
[#NormalTok("classification_summary(");],
[#NormalTok("    y_test,");],
[#NormalTok("    test_prob,");],
[#NormalTok("    threshold");#OperatorTok("=");#NormalTok("cost_threshold,");],
[#NormalTok(")");],));
#Skylighting(([#NormalTok("{'threshold': 0.16666666666666666,");],
[#NormalTok(" 'TP': np.int64(58),");],
[#NormalTok(" 'FP': np.int64(6),");],
[#NormalTok(" 'FN': np.int64(6),");],
[#NormalTok(" 'TN': np.int64(101),");],
[#NormalTok(" 'accuracy': 0.9298245614035088,");],
[#NormalTok(" 'precision': 0.90625,");],
[#NormalTok(" 'recall': 0.90625,");],
[#NormalTok(" 'f1': 0.90625}");],));
This lower threshold prioritizes recall. It predicts malignant more aggressively because false negatives are assumed to be more costly.

#block[
#callout(
body: 
[
The cost-based threshold formula assumes that the fitted probabilities are reasonably calibrated.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== ROC Curve and AUC
<roc-curve-and-auc-1>
ROC analysis evaluates ranking quality across thresholds. It does not depend on a single fixed threshold.

For a threshold $c$, define

$ T P R \( c \) = Pr \( hat(p) \( X \) > c divides Y = 1 \) = frac(T P \( c \), T P \( c \) + F N \( c \)) $

and

$ F P R \( c \) = Pr \( hat(p) \( X \) > c divides Y = 0 \) = frac(F P \( c \), F P \( c \) + T N \( c \)) . $

The ROC curve plots $T P R \( c \)$ against $F P R \( c \)$ as the threshold varies over the range of possible scores.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" roc_curve, roc_auc_score");],
[],
[#NormalTok("fpr, tpr, roc_thresholds ");#OperatorTok("=");#NormalTok(" roc_curve(y_test, test_prob)");],
[#NormalTok("auc ");#OperatorTok("=");#NormalTok(" roc_auc_score(y_test, test_prob)");],
[],
[#NormalTok("plt.plot(fpr, tpr, label");#OperatorTok("=");#SpecialStringTok("f\"Logistic regression AUC = ");#SpecialCharTok("{");#NormalTok("auc");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.plot([");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], [");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("], ");#StringTok("\"k--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"random guessing\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"false positive rate\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"true positive rate\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"ROC Curve\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\1/logistic_files/figure-typst/cell-17-output-1.svg"))

AUC is the area under the ROC curve. It can be interpreted as

$ A U C = Pr (s \( X^(+) \) > s \( X^(-) \)) \, $

up to small corrections for ties, where $X^(+)$ is a randomly selected positive observation, $X^(-)$ is a randomly selected negative observation, and $s \( dot.op \)$ is the model score.

Thus AUC evaluates ranking quality. It does not evaluate whether the predicted probabilities are numerically calibrated.

== Precision-Recall Curve
<precision-recall-curve-2>
Precision-recall curves are often useful when the positive class is rare or when performance on the positive class is the main concern.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" precision_recall_curve, average_precision_score");],
[],
[#NormalTok("precision, recall, pr_thresholds ");#OperatorTok("=");#NormalTok(" precision_recall_curve(y_test, test_prob)");],
[#NormalTok("avg_precision ");#OperatorTok("=");#NormalTok(" average_precision_score(y_test, test_prob)");],
[],
[#NormalTok("plt.plot(recall, precision, label");#OperatorTok("=");#SpecialStringTok("f\"AP = ");#SpecialCharTok("{");#NormalTok("avg_precision");#SpecialCharTok(":.3f}");#SpecialStringTok("\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"recall\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"precision\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Precision-Recall Curve\"");#NormalTok(")");],
[#NormalTok("plt.legend()");],));
#box(image("contents\\1/logistic_files/figure-typst/cell-18-output-1.svg"))

Average precision summarizes the precision-recall curve. Compared with ROC AUC, it is often more sensitive to false positives when the positive class is rare.

== Probability Quality
<probability-quality-1>
Logistic regression directly estimates probabilities, so probability quality is also important.

Two common proper scoring rules are Brier score and log loss:

$ upright("Brier") = 1 / n sum_(i = 1)^n \( y_i - hat(p)_i \)^2 \, $

and

$ upright("LogLoss") = - 1 / n sum_(i = 1)^n [y_i log \( hat(p)_i \) + \( 1 - y_i \) log \( 1 - hat(p)_i \)] . $

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" brier_score_loss, log_loss");],
[],
[#NormalTok("probability_scores ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"brier_score\"");#NormalTok(": brier_score_loss(y_test, test_prob),");],
[#NormalTok("    ");#StringTok("\"log_loss\"");#NormalTok(": log_loss(y_test, test_prob),");],
[#NormalTok("}");],
[],
[#NormalTok("probability_scores");],));
#Skylighting(([#NormalTok("{'brier_score': 0.06368785859728307, 'log_loss': 0.2183157001746612}");],));
Calibration curves diagnose whether predicted probabilities are numerically meaningful.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.calibration ");#ImportTok("import");#NormalTok(" CalibrationDisplay");],
[],
[#NormalTok("CalibrationDisplay.from_predictions(");],
[#NormalTok("    y_test,");],
[#NormalTok("    test_prob,");],
[#NormalTok("    n_bins");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok("    name");#OperatorTok("=");#StringTok("\"Logistic regression\"");#NormalTok(",");],
[#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Calibration Curve\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'Calibration Curve')");],));
#block[
#box(image("contents\\1/logistic_files/figure-typst/cell-20-output-2.svg"))

]
If a model predicts probability near $0.8$, then a well-calibrated model should have an observed positive frequency near $80 %$ among observations with similar predicted probabilities.

== Decision Boundary
<decision-boundary>
With two predictors, we can visualize the fitted probability surface and the decision boundary.

#Skylighting(([#NormalTok("X2 ");#OperatorTok("=");#NormalTok(" cancer.data[[");#StringTok("\"mean radius\"");#NormalTok(", ");#StringTok("\"mean texture\"");#NormalTok("]]");],
[#NormalTok("y2 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" cancer.target");],
[],
[#NormalTok("X2_train, X2_test, y2_train, y2_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X2,");],
[#NormalTok("    y2,");],
[#NormalTok("    test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(",");],
[#NormalTok("    stratify");#OperatorTok("=");#NormalTok("y2,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("2");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("boundary_model ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LogisticRegression(penalty");#OperatorTok("=");#VariableTok("None");#NormalTok(", max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok("),");],
[#NormalTok(")");],
[#NormalTok("boundary_model.fit(X2_train, y2_train)");],
[],
[#NormalTok("x0_min, x0_max ");#OperatorTok("=");#NormalTok(" X2.iloc[:, ");#DecValTok("0");#NormalTok("].");#BuiltInTok("min");#NormalTok("() ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(", X2.iloc[:, ");#DecValTok("0");#NormalTok("].");#BuiltInTok("max");#NormalTok("() ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("x1_min, x1_max ");#OperatorTok("=");#NormalTok(" X2.iloc[:, ");#DecValTok("1");#NormalTok("].");#BuiltInTok("min");#NormalTok("() ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(", X2.iloc[:, ");#DecValTok("1");#NormalTok("].");#BuiltInTok("max");#NormalTok("() ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("xx0, xx1 ");#OperatorTok("=");#NormalTok(" np.meshgrid(");],
[#NormalTok("    np.linspace(x0_min, x0_max, ");#DecValTok("300");#NormalTok("),");],
[#NormalTok("    np.linspace(x1_min, x1_max, ");#DecValTok("300");#NormalTok("),");],
[#NormalTok(")");],
[],
[#NormalTok("grid_points ");#OperatorTok("=");#NormalTok(" pd.DataFrame(");],
[#NormalTok("    {");],
[#NormalTok("        ");#StringTok("\"mean radius\"");#NormalTok(": xx0.ravel(),");],
[#NormalTok("        ");#StringTok("\"mean texture\"");#NormalTok(": xx1.ravel(),");],
[#NormalTok("    }");],
[#NormalTok(")");],
[],
[#NormalTok("zz ");#OperatorTok("=");#NormalTok(" boundary_model.predict_proba(grid_points)[:, ");#DecValTok("1");#NormalTok("].reshape(xx0.shape)");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("plt.contourf(xx0, xx1, zz, levels");#OperatorTok("=");#DecValTok("20");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.35");#NormalTok(")");],
[#NormalTok("plt.contour(xx0, xx1, zz, levels");#OperatorTok("=");#NormalTok("[");#FloatTok("0.5");#NormalTok("], colors");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linewidths");#OperatorTok("=");#DecValTok("2");#NormalTok(")");],
[#NormalTok("plt.scatter(X2_test.iloc[:, ");#DecValTok("0");#NormalTok("], X2_test.iloc[:, ");#DecValTok("1");#NormalTok("], c");#OperatorTok("=");#NormalTok("y2_test, edgecolor");#OperatorTok("=");#StringTok("\"k\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"mean radius\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"mean texture\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Logistic Regression Probability Surface\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],));
]
#box(image("contents\\1/logistic_files/figure-typst/cell-21-output-2.svg"))

The $0.5$ decision boundary is linear in the original predictors because the log-odds are linear. Other thresholds produce parallel boundaries in the two-predictor unpenalized logistic regression model.

== Penalized Logistic Regression
<penalized-logistic-regression>
Logistic regression can be regularized in the same spirit as ridge regression and lasso.

The unpenalized logistic regression estimator solves

$ hat(beta) = arg min_beta {- ell \( beta \)} . $

Ridge logistic regression solves

\$\$
\\hat\\beta\_{\\ridge}
=
\\arg\\min\_\\beta
\\left\\{
-\\ell(\\beta)
+
\\lambda\\sum\_{j=1}^p\\beta\_j^2
\\right\\}.
\$\$

Lasso logistic regression solves

\$\$
\\hat\\beta\_{\\lasso}
=
\\arg\\min\_\\beta
\\left\\{
-\\ell(\\beta)
+
\\lambda\\sum\_{j=1}^p|\\beta\_j|
\\right\\}.
\$\$

The intercept is usually not penalized. Predictors should usually be standardized before penalized logistic regression because the penalty depends on coefficient scale.

In #NormalTok("sklearn");, the parameter #NormalTok("C"); controls inverse regularization strength:

$ C = 1 / lambda . $

Smaller #NormalTok("C"); means stronger regularization.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[],
[#NormalTok("penalized_pipe ");#OperatorTok("=");#NormalTok(" make_pipeline(");],
[#NormalTok("    StandardScaler(),");],
[#NormalTok("    LogisticRegression(");],
[#NormalTok("        penalty");#OperatorTok("=");#StringTok("\"l1\"");#NormalTok(",");],
[#NormalTok("        solver");#OperatorTok("=");#StringTok("\"liblinear\"");#NormalTok(",");],
[#NormalTok("        max_iter");#OperatorTok("=");#DecValTok("5000");#NormalTok(",");],
[#NormalTok("    ),");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"logisticregression__C\"");#NormalTok(": np.logspace(");#OperatorTok("-");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("20");#NormalTok("),");],
[#NormalTok("}");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    penalized_pipe,");],
[#NormalTok("    param_grid");#OperatorTok("=");#NormalTok("param_grid,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    scoring");#OperatorTok("=");#StringTok("\"roc_auc\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[],
[#NormalTok("grid.best_params_");],));
#block[
#Skylighting(([#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1135: FutureWarning: 'penalty' was deprecated in version 1.8 and will be removed in 1.10. To avoid this warning, leave 'penalty' set to its default value and use 'l1_ratio' or 'C' instead. Use l1_ratio=0 instead of penalty='l2', l1_ratio=1 instead of penalty='l1', and C=np.inf instead of penalty=None.");],
[#NormalTok("  warnings.warn(");],
[#NormalTok("D:\\Codes\\Notes\\su26\\.venv\\Lib\\site-packages\\sklearn\\linear_model\\_logistic.py:1160: UserWarning: Inconsistent values: penalty=l1 with l1_ratio=0.0. penalty is deprecated. Please use l1_ratio only.");],
[#NormalTok("  warnings.warn(");],));
]
#Skylighting(([#NormalTok("{'logisticregression__C': np.float64(4.832930238571752)}");],));
The selected model is available as:

#Skylighting(([#NormalTok("grid.best_estimator_");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.pipeline.Pipeline.html#:~:text=steps,-list%20of%20tuples")[steps #text(fill: rgb("#000"))[steps: list of tuples \
   \
  List of (name of step, estimator) tuples that are to be chained in \
  sequential order. To be compatible with the scikit-learn API, all steps \
  must define \`fit\`. All non-last steps must also define \`transform\`. See \
  :ref:\`Combining Estimators \` for more details.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); \[(\'standardscaler\', ...), (\'logisticregression\', ...)\]],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.pipeline.Pipeline.html#:~:text=transform_input,-list%20of%20str%2C%20default%3DNone")[transform\_input #text(fill: rgb("#000"))[transform\_input: list of str, default=None \
   \
  The names of the :term:\`metadata\` parameters that should be transformed by the \
  pipeline before passing it to the step consuming it. \
   \
  This enables transforming some input arguments to \`\`fit\`\` (other than \`\`X\`\`) \
  to be transformed by the steps of the pipeline up to the step which requires \
  them. Requirement is defined via :ref:\`metadata routing \`. \
  For instance, this can be used to pass a validation set through the pipeline. \
   \
  You can only set this if metadata routing is enabled, which you \
  can enable using \`\`sklearn.set\_config(enable\_metadata\_routing=True)\`\`. \
   \
  .. versionadded:: 1.6]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.pipeline.Pipeline.html#:~:text=memory,-str%20or%20object%20with%20the%20joblib.Memory%20interface%2C%20default%3DNone")[memory #text(fill: rgb("#000"))[memory: str or object with the joblib.Memory interface, default=None \
   \
  Used to cache the fitted transformers of the pipeline. The last step \
  will never be cached, even if it is a transformer. By default, no \
  caching is performed. If a string is given, it is the path to the \
  caching directory. Enabling caching triggers a clone of the transformers \
  before fitting. Therefore, the transformer instance given to the \
  pipeline cannot be inspected directly. Use the attribute \`\`named\_steps\`\` \
  or \`\`steps\`\` to inspect estimators within the pipeline. Caching the \
  transformers is advantageous when fitting is time consuming. See \
  :ref:\`sphx\_glr\_auto\_examples\_neighbors\_plot\_caching\_nearest\_neighbors.py\` \
  for an example on how to enable caching.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.pipeline.Pipeline.html#:~:text=verbose,-bool%2C%20default%3DFalse")[verbose #text(fill: rgb("#000"))[verbose: bool, default=False \
   \
  If True, the time elapsed while fitting each step will be printed as it \
  is completed.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
)
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=copy,-bool%2C%20default%3DTrue")[copy #text(fill: rgb("#000"))[copy: bool, default=True \
   \
  If False, try to avoid a copy and do inplace scaling instead. \
  This is not guaranteed to always work inplace; e.g. if the data is \
  not a NumPy array or scipy.sparse CSR matrix, a copy may still be \
  returned.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_mean,-bool%2C%20default%3DTrue")[with\_mean #text(fill: rgb("#000"))[with\_mean: bool, default=True \
   \
  If True, center the data before scaling. \
  This does not work (and will raise an exception) when attempted on \
  sparse matrices, because centering them entails building a dense \
  matrix which in common use cases is likely to be too large to fit in \
  memory.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.preprocessing.StandardScaler.html#:~:text=with_std,-bool%2C%20default%3DTrue")[with\_std #text(fill: rgb("#000"))[with\_std: bool, default=True \
   \
  If True, scale the data to unit variance (or equivalently, \
  unit standard deviation).]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
)
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=penalty,-%7B%27l1%27%2C%20%27l2%27%2C%20%27elasticnet%27%2C%20None%7D%2C%20default%3D%27l2%27")[penalty #text(fill: rgb("#000"))[penalty: {\'l1\', \'l2\', \'elasticnet\', None}, default=\'l2\' \
   \
  Specify the norm of the penalty: \
   \
  \- \`None\`: no penalty is added; \
  \- \`\'l2\'\`: add a L2 penalty term and it is the default choice; \
  \- \`\'l1\'\`: add a L1 penalty term; \
  \- \`\'elasticnet\'\`: both L1 and L2 penalty terms are added. \
   \
  .. warning:: \
  Some penalties may not work with some solvers. See the parameter \
  \`solver\` below, to know the compatibility between the penalty and \
  solver. \
   \
  .. versionadded:: 0.19 \
  l1 penalty with SAGA solver (allowing \'multinomial\' + L1) \
   \
  .. deprecated:: 1.8 \
  \`penalty\` was deprecated in version 1.8 and will be removed in 1.10. \
  Use \`l1\_ratio\` instead. \`l1\_ratio=0\` for \`penalty=\'l2\'\`, \`l1\_ratio=1\` for \
  \`penalty=\'l1\'\` and \`l1\_ratio\` set to any float between 0 and 1 for \
  \`\'penalty=\'elasticnet\'\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); \'l1\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=C,-float%2C%20default%3D1.0")[C #text(fill: rgb("#000"))[C: float, default=1.0 \
   \
  Inverse of regularization strength; must be a positive float. \
  Like in support vector machines, smaller values specify stronger \
  regularization. \`C=np.inf\` results in unpenalized logistic regression. \
  For a visual example on the effect of tuning the \`C\` parameter \
  with an L1 penalty, see: \
  :ref:\`sphx\_glr\_auto\_examples\_linear\_model\_plot\_logistic\_path.py\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); np.float64(4.832930238571752)],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=l1_ratio,-float%2C%20default%3D0.0")[l1\_ratio #text(fill: rgb("#000"))[l1\_ratio: float, default=0.0 \
   \
  The Elastic-Net mixing parameter, with \`0 \<= l1\_ratio \<= 1\`. Setting \
  \`l1\_ratio=1\` gives a pure L1-penalty, setting \`l1\_ratio=0\` a pure L2-penalty. \
  Any value between 0 and 1 gives an Elastic-Net penalty of the form \
  \`l1\_ratio \* L1 + (1 - l1\_ratio) \* L2\`. \
   \
  .. warning:: \
  Certain values of \`l1\_ratio\`, i.e. some penalties, may not work with some \
  solvers. See the parameter \`solver\` below, to know the compatibility between \
  the penalty and solver. \
   \
  .. versionchanged:: 1.8 \
  Default value changed from None to 0.0. \
   \
  .. deprecated:: 1.8 \
  \`None\` is deprecated and will be removed in version 1.10. Always use \
  \`l1\_ratio\` to specify the penalty type.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=dual,-bool%2C%20default%3DFalse")[dual #text(fill: rgb("#000"))[dual: bool, default=False \
   \
  Dual (constrained) or primal (regularized, see also \
  :ref:\`this equation \`) formulation. Dual formulation \
  is only implemented for l2 penalty with liblinear solver. Prefer \`dual=False\` \
  when n\_samples \> n\_features.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=tol,-float%2C%20default%3D1e-4")[tol #text(fill: rgb("#000"))[tol: float, default=1e-4 \
   \
  Tolerance for stopping criteria.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0001],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=fit_intercept,-bool%2C%20default%3DTrue")[fit\_intercept #text(fill: rgb("#000"))[fit\_intercept: bool, default=True \
   \
  Specifies if a constant (a.k.a. bias or intercept) should be \
  added to the decision function.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=intercept_scaling,-float%2C%20default%3D1")[intercept\_scaling #text(fill: rgb("#000"))[intercept\_scaling: float, default=1 \
   \
  Useful only when the solver \`liblinear\` is used \
  and \`self.fit\_intercept\` is set to \`True\`. In this case, \`x\` becomes \
  \`\[x, self.intercept\_scaling\]\`, \
  i.e. a \"synthetic\" feature with constant value equal to \
  \`intercept\_scaling\` is appended to the instance vector. \
  The intercept becomes \
  \`\`intercept\_scaling \* synthetic\_feature\_weight\`\`. \
   \
  .. note:: \
  The synthetic feature weight is subject to L1 or L2 \
  regularization as all other features. \
  To lessen the effect of regularization on synthetic feature weight \
  (and therefore on the intercept) \`intercept\_scaling\` has to be increased.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=class_weight,-dict%20or%20%27balanced%27%2C%20default%3DNone")[class\_weight #text(fill: rgb("#000"))[class\_weight: dict or \'balanced\', default=None \
   \
  Weights associated with classes in the form \`\`{class\_label: weight}\`\`. \
  If not given, all classes are supposed to have weight one. \
   \
  The \"balanced\" mode uses the values of y to automatically adjust \
  weights inversely proportional to class frequencies in the input data \
  as \`\`n\_samples / (n\_classes \* np.bincount(y))\`\`. \
   \
  Note that these weights will be multiplied with sample\_weight (passed \
  through the fit method) if sample\_weight is specified. \
   \
  .. versionadded:: 0.17 \
  \*class\_weight=\'balanced\'\*]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=random_state,-int%2C%20RandomState%20instance%2C%20default%3DNone")[random\_state #text(fill: rgb("#000"))[random\_state: int, RandomState instance, default=None \
   \
  Used when \`\`solver\`\` == \'sag\', \'saga\' or \'liblinear\' to shuffle the \
  data. See :term:\`Glossary \` for details.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=solver,-%7B%27lbfgs%27%2C%20%27liblinear%27%2C%20%27newton-cg%27%2C%20%27newton-cholesky%27%2C%20%27sag%27%2C%20%27saga%27%7D%2C%20%20%20%20%20%20%20%20%20%20%20%20%20default%3D%27lbfgs%27")[solver #text(fill: rgb("#000"))[solver: {\'lbfgs\', \'liblinear\', \'newton-cg\', \'newton-cholesky\', \'sag\', \'saga\'}, default=\'lbfgs\' \
   \
  Algorithm to use in the optimization problem. Default is \'lbfgs\'. \
  To choose a solver, you might want to consider the following aspects: \
   \
  \- \'lbfgs\' is a good default solver because it works reasonably well for a wide \
  class of problems. \
  \- For :term:\`multiclass\` problems (\`n\_classes \>= 3\`), all solvers except \
  \'liblinear\' minimize the full multinomial loss, \'liblinear\' will raise an \
  error. \
  \- \'newton-cholesky\' is a good choice for \
  \`n\_samples\` \>\> \`n\_features \* n\_classes\`, especially with one-hot encoded \
  categorical features with rare categories. Be aware that the memory usage \
  of this solver has a quadratic dependency on \`n\_features \* n\_classes\` \
  because it explicitly computes the full Hessian matrix. \
  \- For small datasets, \'liblinear\' is a good choice, whereas \'sag\' \
  and \'saga\' are faster for large ones; \
  \- \'liblinear\' can only handle binary classification by default. To apply a \
  one-versus-rest scheme for the multiclass setting one can wrap it with the \
  :class:\`\~sklearn.multiclass.OneVsRestClassifier\`. \
   \
  .. warning:: \
  The choice of the algorithm depends on the penalty chosen (\`l1\_ratio=0\` \
  for L2-penalty, \`l1\_ratio=1\` for L1-penalty and \`0 \< l1\_ratio \< 1\` for \
  Elastic-Net) and on (multinomial) multiclass support: \
   \
  \================= ======================== ====================== \
  solver l1\_ratio multinomial multiclass \
  \================= ======================== ====================== \
  \'lbfgs\' l1\_ratio=0 yes \
  \'liblinear\' l1\_ratio=1 or l1\_ratio=0 no \
  \'newton-cg\' l1\_ratio=0 yes \
  \'newton-cholesky\' l1\_ratio=0 yes \
  \'sag\' l1\_ratio=0 yes \
  \'saga\' 0\<=l1\_ratio\<=1 yes \
  \================= ======================== ====================== \
   \
  .. note:: \
  \'sag\' and \'saga\' fast convergence is only guaranteed on features \
  with approximately the same scale. You can preprocess the data with \
  a scaler from :mod:\`sklearn.preprocessing\`. \
   \
  .. seealso:: \
  Refer to the :ref:\`User Guide \` for more \
  information regarding :class:\`LogisticRegression\` and more specifically the \
  :ref:\`Table \` \
  summarizing solver/penalty supports. \
   \
  .. versionadded:: 0.17 \
  Stochastic Average Gradient (SAG) descent solver. Multinomial support in \
  version 0.18. \
  .. versionadded:: 0.19 \
  SAGA solver. \
  .. versionchanged:: 0.22 \
  The default solver changed from \'liblinear\' to \'lbfgs\' in 0.22. \
  .. versionadded:: 1.2 \
  newton-cholesky solver. Multinomial support in version 1.6.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); \'liblinear\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=max_iter,-int%2C%20default%3D100")[max\_iter #text(fill: rgb("#000"))[max\_iter: int, default=100 \
   \
  Maximum number of iterations taken for the solvers to converge.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 5000],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=verbose,-int%2C%20default%3D0")[verbose #text(fill: rgb("#000"))[verbose: int, default=0 \
   \
  For the liblinear and lbfgs solvers set verbose to any positive \
  number for verbosity.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=warm_start,-bool%2C%20default%3DFalse")[warm\_start #text(fill: rgb("#000"))[warm\_start: bool, default=False \
   \
  When set to True, reuse the solution of the previous call to fit as \
  initialization, otherwise, just erase the previous solution. \
  Useless for liblinear solver. See :term:\`the Glossary \`. \
   \
  .. versionadded:: 0.17 \
  \*warm\_start\* to support \*lbfgs\*, \*newton-cg\*, \*sag\*, \*saga\* solvers.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.linear_model.LogisticRegression.html#:~:text=n_jobs,-int%2C%20default%3DNone")[n\_jobs #text(fill: rgb("#000"))[n\_jobs: int, default=None \
   \
  Does not have any effect. \
   \
  .. deprecated:: 1.8 \
  \`n\_jobs\` is deprecated in version 1.8 and will be removed in 1.10.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
)
#block[
#callout(
body: 
[
Regularization changes the fitted probabilities by changing the estimated coefficients. Threshold tuning changes only the final decision rule.

]
, 
title: 
[
Regularization and model tuning
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Summary
<summary-2>
Logistic regression:

- models binary outcomes through class probabilities;
- uses the logit link to make log-odds linear in the predictors;
- estimates coefficients by maximum likelihood;
- interprets coefficients through odds ratios;
- produces both probabilities and class predictions;
- requires a threshold for hard classification;
- can be evaluated by threshold-based metrics, ROC AUC, precision-recall curves, and probability-quality metrics;
- is often combined with regularization in predictive workflows.

Use #NormalTok("sklearn"); when prediction, pipelines, cross-validation, threshold tuning, and model selection are the main goal.

#part[Nonparametric Supervised Learning]
= Tree-Based Methods
<tree-based-methods>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
A decision tree is another nonparametric method, which learns a collection of simple if-then rules directly from the data.

The basic idea is:

+ Split the feature space into regions.
+ Continue splitting each region into smaller regions.
+ Use the observations inside each final region to make predictions.

#example(title: [Example: A Classification Tree])[
~

#box(image("contents\\2/tree_files/figure-typst/cell-2-output-1.svg"))

This is a classification tree. The tree repeatedly asks simple questions such as

- Is #NormalTok("x[0] <= 2.45");?
- Is #NormalTok("x[1] <= 1.75");?

Each split divides the feature space into smaller regions.

This tree actually create the following splits in the feature space.

#box(image("contents\\2/tree_files/figure-typst/cell-3-output-1.svg"))

] <exm->
Based on the idea of a decision tree, a tree makes decisions by repeatedly asking questions of the form $x_j lt.eq c$. Therefore, a tree has two important properties:

- It depends directly on the original features.
- The scale of a feature is usually not important.

As a result, we should expect that a tree is:

- sensitive to feature construction or feature combinations: A tree can only split on the features that are provided. If the useful signal is hidden in a combination such as $x_1 + x_2$ or $x_1 x_2$, a tree may need many splits to approximate that relationship.
- not sensitive to monotone transformations of a feature: For example, replacing $x$ by $log \( x \)$ or $2 x + 5$ does not change the ordering of the observations. Since tree splits mainly depend on ordering, the tree can usually produce an equivalent split after the transformation.

== CART: Classification and Regression Trees
<cart-classification-and-regression-trees>
There are many algorithms for constructing decision trees. The most common one is called CART (Classification and Regression Trees).

CART has the following properties:

- It creates only binary splits;
- It can perform both classification and regression tasks:
  - For classification, common splitting criteria include Gini impurity and entropy;
  - For regression, common splitting criteria include residual sum of squares (RSS) and mean squared error (MSE).

=== Splitting a Dataset
<splitting-a-dataset>
At each step, CART searches over possible splits and chooses the split that produces the largest reduction in impurity (or prediction error).

#block[
#callout(
body: 
[
#strong[Inputs:] A dataset $S = \[ upright("features") \, upright("target") \]$

#strong[Outputs:] The best split $\( k \, t \)$

+ For each feature $x_k$:
  + For each candidate split value $t$:
    + Split the dataset into two subsets: \$G\_l=\\qty{\\text{data with }x\_k\\le t}\$, \$G\_r=\\qty{\\text{data with }x\_k\>t}\$.
    + Compute the split cost function $J \( k \, t \)$
    + Keep the best split found so far
+ Return the split $\( k \, t \)$ with the smallest cost

]
, 
title: 
[
Algorithm: Split the Dataset
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
The splitting algorithm is applied recursively.

#block[
#callout(
body: 
[
#strong[Inputs:] A labeled dataset $S$ and a maximal tree depth #NormalTok("max_depth");

#strong[Outputs:] A decision tree

+ Start with the original dataset $S$
+ If the node is not pure and stopping conditions are not met:
  + Find the best split
  + Split the node into: $G_l$ and $G_r$
  + Apply the same procedure recursively to both child nodes
+ Stop when:
  - the maximal depth is reached, or
  - the node becomes pure, or
  - further splitting is impossible

]
, 
title: 
[
Algorithm: CART
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
When making predictions, a classification tree uses the most common class label in a region as the predicted value, while a regression tree uses the mean of the response values in the region as the predicted value.

=== Classification Trees: Gini Impurity
<classification-trees-gini-impurity>
Classification trees are used when the response variable is categorical. A classification tree partitions the feature space into piecewise constant regions, where each region predicts either a class label or class probabilities.

In these notes, we use Gini impurity to measure the quality of a split.

Assume that a node contains $n$ observations divided into $K$ classes. Let $p_i = n_i / n$ be the proportion of class $i$. If we classify observations according to the class proportions:

- the probability an observation belongs to class $i$ is $p_i$
- the probability we incorrectly classify it is $1 - p_i$

Therefore the probability of misclassifying an observation from class $i$ is

$ p_i \( 1 - p_i \) . $

Summing over all classes gives

$ sum_(i = 1)^K p_i \( 1 - p_i \) . $

Since

$ sum_(i = 1)^K p_i = 1 \, $

we obtain

\$\$
\\gini
=\\sum\_{i=1}^K p\_i(1-p\_i)
=1-\\sum\_{i=1}^K p\_i^2.
\$\$

#definition(title: [Gini Impurity])[
The #strong[Gini impurity] of a node is

\$\$
\\gini
=1-\\sum\_{i=1}^K p\_i^2,
\$\$

where $p_i$ is the proportion of class $i$ inside the node.

] <def-gini>
#example(title: [Pure node])[
Suppose a node contains observations from only one class.

Then one of the probabilities equals 1 and all others equal 0.

Therefore

\$\$
\\gini=1-1^2=0.
\$\$

This is the minimum possible impurity.

A node with Gini impurity 0 is called a pure node.

] <exm->
#example(title: [Two-Class Example])[
Suppose we have two classes.

Let

$ p_2 = 1 - p_1 . $

Then

\$\$
\\gini
=1-p\_1^2-(1-p\_1)^2
=2p\_1-2p\_1^2.
\$\$

When:

- $p_1 = 0$ or $1$, the impurity is 0;
- $p_1 = 0.5$, the impurity is maximized.

Therefore, impurity is largest when the classes are perfectly balanced.

] <exm->
The impurity of a node alone is not enough. CART evaluates a split by examining the impurity of the child nodes after splitting.

Suppose a node $G$ is split into $G_l$ and $G_r$. The split cost is

\$\$
J
=\\frac{|G\_l|}{|G|}\\gini(G\_l)
+\\frac{|G\_r|}{|G|}\\gini(G\_r).
\$\$

A good split produces child nodes with low impurity, ideally creating nodes that are close to pure.

#block[
#callout(
body: 
[
Entropy is another popular impurity measure. Its formula is

$ upright(E n t r o p y) = - sum_(i = 1)^K p_i log \( p_i \) . $

Entropy and Gini impurity usually produce very similar trees.

Because Gini impurity is slightly simpler computationally and conceptually, we mainly focus on it.

]
, 
title: 
[
Entropy
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Regression Trees: RSS
<regression-trees-rss>
Regression trees are used when the response variable is quantitative. Instead of predicting a class label, they predict numerical values.

Suppose a terminal node contains responses $y_1$, $y_2$, $dots.h$, $y_n$. The prediction for that region is usually the sample mean: $ hat(y) = 1 / n sum_(i = 1)^n y_i . $

Therefore, regression trees approximate the regression function using piecewise constant regions.

For regression trees, CART typically minimizes the residual sum of squares (RSS). Sometimes the mean squared error (MSE) is used instead. Since MSE differs from RSS only by a constant scaling factor, minimizing one is equivalent to minimizing the other.

Suppose a split divides the data into two regions $G_l$ and $G_r$. The split cost is

\$\$
\\rss
=
\\sum\_{i\\in G\_l}(y\_i-\\bar y\_l)^2
+
\\sum\_{i\\in G\_r}(y\_i-\\bar y\_r)^2,
\$\$

where $macron(y)_l$ and $macron(y)_r$ are the mean responses within the two regions. The best split is the one that minimizes this quantity.

=== Trees are local
<trees-are-local>
A tree makes predictions using only observations inside a small region of the feature space. Suppose a tree partitions the feature space into regions. The prediction at a point $x$ depends only on the region containing $x$. As a result, tree predictions are local:

- nearby regions may have very different predictions
- only observations in the same local region affect the prediction
- changing distant observations usually does not affect the prediction

This is similar in spirit to KNN, where prediction also depends primarily on nearby observations.

=== Trees are nonlinear
<trees-are-nonlinear>
A tree creates many if-then rules. Because of these recursive splits:

- the prediction function can change abruptly
- variable effects depend on the region
- interactions are created automatically

The prediction surface is therefore discontinuous and piecewise constant. Therefore, trees are nonlinear models.

=== Automatic interaction effects
<automatic-interaction-effects>
One important property of trees is that they automatically create interaction effects.

For example, consider a tree with depth 3. One path through the tree may look like:

- if $x_1 lt.eq 1$
- and $x_2 lt.eq 2$
- and $x_3 lt.eq 3$
- then predict $y = 1.1$

Notice that the prediction depends on the combination of all three conditions simultaneously. Therefore, the effect of one variable may depend on the values of earlier splitting variables. In other words, the effect of $x_3$ is not independent of $x_1$ and $x_2$. The split on $x_3$ is only relevant inside the region defined by the earlier splits.

Therefore, trees naturally model interactions between variables.

This is very different from a standard additive linear model such as

$ f \( x \) = beta_0 + beta_1 x_1 + beta_2 x_2 + beta_3 x_3 \, $

where each variable contributes independently unless explicit interaction terms like $x_1 x_2$ are manually added.

== Tuning hyperparameters
<tuning-hyperparameters>
Building a decision tree is the same as splitting the training dataset. If we are alllowed to keep splitting it, it is possible to get to a case that each end node is pure: the Gini impurity is 0, or every element has the same response variable locally.

#example(title: [ALMOST all end nodes are pure])[
~

Click to expand.
In this example, we let the tree grow as further as possible. It only stops when (almost) all end nodes are pure, even if the end nodes only contain ONE element (like \#6 and \#11).

#box(image("contents\\2/tree_files/figure-typst/cell-4-output-1.svg"))

In this example there is one exception. \#13 node is not pure. We could list all data in node \#13.

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[x\[0\]], table.cell(align: right)[x\[1\]], table.cell(align: right)[y],),
  table.hline(),
  table.cell(align: horizon)[0], [4.8], [1.8], [1],
  table.cell(align: horizon)[1], [4.8], [1.8], [2],
  table.cell(align: horizon)[2], [4.8], [1.8], [2],
)
All the data points in this node has the same feature while their labels are different. They cannot be split further purely based on features.

] <exm->
As the tree continues splitting the feature space into smaller regions, it learns increasingly fine details of the training set. Although this increases flexibility, it can also make the model overly sensitive to noise. Therefore, we usually do not want the tree to grow indefinitely.

There are two common ways to control a single tree growth:

+ Pruning: first grow a large tree, then remove unnecessary branches afterward.
+ Pre-pruning: stop the tree early by imposing restrictions during training.

=== Pruning
<pruning>
Pruning means removing branches from a tree. The pruning method introduced in CART is called Minimal Cost-Complexity Pruning (MCCP).

The idea is very similar to regularization in ridge or lasso regression: we balance goodness of fit against model complexity by adding a penalty term. In MCCP, the penalty is proportional to the number of terminal nodes (leaves) in the tree.

More specifically, the cost function is modified by adding a complexity penalty controlled by the parameter #NormalTok("ccp_alpha");. The parameter #NormalTok("ccp_alpha"); is called the complexity parameter and is always $gt.eq 0$. Let $T$ be a subtree, and let $\| T \|$ denote the number of terminal nodes. The cost-complexity criterion is $ C_alpha \( T \) = J \( T \) + alpha \| T \| \, $ where:

- $J \( T \)$ measures the training error,
- $\| T \|$ measures tree complexity through the number of terminal nodes,
- $alpha$ is corresponding to #NormalTok("ccp_alpha"); in the notes.

This has the same general structure as regularized regression: $upright("loss") + upright("penalty")$.

The tuning parameter $alpha$ controls how expensive it is to add another leaf. If a split reduces the training error by only a small amount, it may not be worth keeping when $alpha$ is large. When $alpha = 0$, there is no complexity penalty, so the procedure behaves like an ordinary decision tree and larger trees are generally preferred.

When applying MCCP, we typically begin with a large tree and then compute the #NormalTok("ccp_alpha"); path, which contains the critical values where the tree structure changes. Each critical value corresponds to a different subtree produced by pruning. We then use validation or cross-validation to compare these candidate subtrees and choose the best value of #NormalTok("ccp_alpha");.

If several values of #NormalTok("ccp_alpha"); achieve similar validation performance, we usually prefer the simpler tree. Therefore, among models with similar test or validation scores, a larger #NormalTok("ccp_alpha"); is often preferred because it produces a smaller and more stable tree.

=== Pre-pruning
<pre-pruning>
We often impose some early stopping conditions to limit the growth of a tree. This strategy is called pre-pruning. Some common early stopping conditions are:

- #NormalTok("max_depth");: maximum tree depth
- #NormalTok("min_samples_split");: minimum number of observations required to split a node
- #NormalTok("min_samples_leaf");: minimum number of observations in a terminal node
- #NormalTok("max_leaf_nodes");: maximum number of leaves

Smaller trees are usually more stable but may underfit. Larger trees are more flexible but may overfit. A larger tree is not automatically better, even if it achieves lower training error.

However, pre-pruning can be greedy. A split that appears only mildly useful at an early stage may later enable highly informative splits deeper in the tree. If we stop the tree too early, we may miss important structure in the data.

Therefore, in modern practice, pre-pruning is usually not the primary method for selecting the final model complexity. Instead, we mainly rely on pruning by choosing the best #NormalTok("ccp_alpha"); through validation or cross-validation. Pre-pruning is often used only as a guardrail to prevent the initial tree from becoming excessively large. In practice, we usually set relatively mild early stopping limits to stabilize the tree-growing process and then rely on pruning to determine the final tree size.

#block[
#callout(
body: 
[
In classical CART, #NormalTok("ccp_alpha"); is the primary complexity parameter and is usually selected by cross-validation after growing a large tree.

In modern practice, pre-pruning parameters and #NormalTok("ccp_alpha"); are often tuned together, especially for computational efficiency and stability. In other words, methods such as #NormalTok("GridSearchCV"); can be used to tune all hyperparameters simultaneously.

However, when the search space becomes too large, this approach can become computationally expensive. In that case, we often return to the more traditional CART-style strategy: we first coarsely identify a reasonable range for the early stopping hyperparameters and then fine-tune #NormalTok("ccp_alpha");.

]
, 
title: 
[
Tuning in practice
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Trees in Python
<trees-in-python>
We use #NormalTok("DecisionTreeClassifier"); and #NormalTok("DecisionTreeRegressor"); from #NormalTok("sklearn.tree"); to implement decision tree models. The API is almost identical to other #NormalTok("sklearn"); models: #NormalTok(".fit()");, #NormalTok(".predict()");, #NormalTok(".score()");, and other familiar methods are used in the same way.

+ We could set #NormalTok("max_depth");, #NormalTok("min_samples_leaf");, #NormalTok("ccp_alpha");, etc. for the tree model where their meaning is straightforward.
+ The method #NormalTok(".cost_complexity_pruning_path()"); can be used to find the critical #NormalTok("ccp_alpha"); values for pruning.
+ We could also set #NormalTok("random_state");. The randomness in #NormalTok("sklearn"); decision trees mainly comes from the internal feature ordering used during the split search. Even when #NormalTok("splitter=\"best\""); is used, #NormalTok("sklearn"); randomly permutes the feature order before evaluating splits. Therefore, when multiple splits produce the same impurity reduction, different trees may be generated unless #NormalTok("random_state"); is fixed.

#block[
#callout(
body: 
[
Decision trees are often described as methods that naturally handle categorical predictors. This is true conceptually, but #NormalTok("sklearn"); decision trees still require numeric input. Therefore categorical predictors must be encoded before fitting the model. For nominal categorical variables, one-hot encoding is usually a safe choice.

However, one-hot encoding for the target variable is not necessary because #NormalTok("sklearn"); classifiers can directly work with class labels.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Example 1: Classify #NormalTok("iris"); dataset
<example-1-classify-iris-dataset>
The #NormalTok("iris"); dataset is a classic classification dataset. The goal is to use four numeric flower measurements to classify the species of iris. The dataset contains 150 observations and 3 classes. More information can be found in the #NormalTok("sklearn"); #link(label("iris-dataset)"))[documentation] for datasets.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_iris");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("iris ");#OperatorTok("=");#NormalTok(" load_iris()");],
[],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" iris.data");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" iris.target");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(X, y, test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
The following code shows the basic #NormalTok("sklearn"); API.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[],
[#NormalTok("clf ");#OperatorTok("=");#NormalTok(" DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("2");#NormalTok(")");],
[#NormalTok("clf.fit(X_train, y_train)");],
[#NormalTok("clf.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.9666666666666667");],));
After fitting the model, we can display the tree using #NormalTok("plot_tree()");. In many real examples, the tree may be too large to read clearly, so we use #NormalTok("matplotlib"); to control the size and resolution of the plot.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" plot_tree");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("5");#NormalTok(", ");#DecValTok("5");#NormalTok("), dpi");#OperatorTok("=");#DecValTok("300");#NormalTok(")");],
[#NormalTok("plot_tree(clf, filled");#OperatorTok("=");#VariableTok("True");#NormalTok(", impurity");#OperatorTok("=");#VariableTok("True");#NormalTok(", node_ids");#OperatorTok("=");#VariableTok("True");#NormalTok(")");#OperatorTok(";");],));
#block[
/ Line 5: #block[
#NormalTok("filled=True"); fills the nodes with colors. #NormalTok("impurity=Ture"); displays the Gini impurity. #NormalTok("node_ids=True"); displays the node ID.
]

]
#box(image("contents\\2/tree_files/figure-typst/cell-8-output-1.svg"))

Now we prune the tree. We first find all critical #NormalTok("ccp_alpha"); values.

#block[
#Skylighting(([#NormalTok("ccp_path ");#OperatorTok("=");#NormalTok(" clf.cost_complexity_pruning_path(X_train, y_train)");],
[#NormalTok("ccp_alphas ");#OperatorTok("=");#NormalTok(" ccp_path.ccp_alphas[:");#OperatorTok("-");#DecValTok("1");#NormalTok("]");],));
]
The last #NormalTok("ccp_alpha"); is usually removed because it is large enough to prune the tree down to a single root node. In most applications, that model is too simple to be useful.

We then train one model for each effective #NormalTok("ccp_alpha");. After fitting the trees, we record both predictive performance and model complexity. Here we use #NormalTok("accuracy"); as our metric, which comes automatically from #NormalTok("clf.score()");.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" accuracy_score");],
[],
[#NormalTok("clfs ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" ccp_alpha ");#KeywordTok("in");#NormalTok(" ccp_alphas:");],
[#NormalTok("    clf ");#OperatorTok("=");#NormalTok(" DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("42");#NormalTok(", ccp_alpha");#OperatorTok("=");#NormalTok("ccp_alpha)");],
[#NormalTok("    clf.fit(X_train, y_train)");],
[#NormalTok("    clfs.append(clf)");],
[],
[#NormalTok("node_counts ");#OperatorTok("=");#NormalTok(" [clf.tree_.node_count ");#ControlFlowTok("for");#NormalTok(" clf ");#KeywordTok("in");#NormalTok(" clfs]");],
[#NormalTok("train_acc ");#OperatorTok("=");#NormalTok(" [clf.score(X_train, y_train) ");#ControlFlowTok("for");#NormalTok(" clf ");#KeywordTok("in");#NormalTok(" clfs]");],
[#NormalTok("test_acc ");#OperatorTok("=");#NormalTok(" [clf.score(X_test, y_test) ");#ControlFlowTok("for");#NormalTok(" clf ");#KeywordTok("in");#NormalTok(" clfs]");],));
]
Here we use a single train/test split. This is a simple validation strategy: the model is fitted on the training set and evaluated on the test set. In addition to accuracy, we also record the number of nodes because it is a useful measure of tree complexity.

A larger tree usually has lower bias but higher variance. A smaller tree is often more interpretable and more stable.

The results are easier to compare visually.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("best_alpha ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.05");],
[],
[#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("2");#NormalTok(", ");#DecValTok("1");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(", ");#DecValTok("7");#NormalTok("), sharex");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].plot(ccp_alphas, node_counts, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", drawstyle");#OperatorTok("=");#StringTok("\"steps-post\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].plot(ccp_alphas, train_acc, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", drawstyle");#OperatorTok("=");#StringTok("\"steps-post\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"train\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].plot(ccp_alphas, test_acc, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", drawstyle");#OperatorTok("=");#StringTok("\"steps-post\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"test\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].axvline(best_alpha, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best ccp_alpha\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].axvline(best_alpha, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best ccp_alpha\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_xlabel(");#StringTok("\"ccp_alpha\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].set_ylabel(");#StringTok("\"number of nodes\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_ylabel(");#StringTok("\"accuracy\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].legend()");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].legend(loc");#OperatorTok("=");#StringTok("\"lower left\"");#NormalTok(")");],));
#block[
/ Line 7: #block[
For pruning-related plots, #NormalTok("drawstyle=\"steps-post\""); is important because the tree structure stays the same within each interval of #NormalTok("ccp_alpha"); values. The tree only changes after reaching the next pruning threshold. Each critical #NormalTok("ccp_alpha"); corresponds to pruning one or more weak internal nodes, so the pruning path is piecewise constant.
]

]
#box(image("contents\\2/tree_files/figure-typst/cell-11-output-1.svg"))

Based on the plot, from 0.0 $lt.eq$ #NormalTok("ccp_alpha"); $<$ 0.04666666666666669, the test accuracy stay the same. Therefore we choose the model with the least number of nodes. So we could choose any #NormalTok("ccp_alpha"); from 0.0 $lt.eq$ #NormalTok("ccp_alpha"); $<$ 0.04666666666666669. Therefore we would like to choose the one with the least number of nodes, which is 0.008130081300813012. Since all values in the range is the same, we hand pick #NormalTok("ccp_alpha=0.05"); for simplicity.

We can now build the final tree and display it.

#Skylighting(([#NormalTok("clf ");#OperatorTok("=");#NormalTok(" DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("42");#NormalTok(", ccp_alpha");#OperatorTok("=");#NormalTok("best_alpha)");],
[#NormalTok("clf.fit(X_train, y_train)");],
[#NormalTok("plot_tree(clf, filled");#OperatorTok("=");#VariableTok("True");#NormalTok(", impurity");#OperatorTok("=");#VariableTok("True");#NormalTok(", node_ids");#OperatorTok("=");#VariableTok("True");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\2/tree_files/figure-typst/cell-12-output-1.svg"))

#block[
#callout(
body: 
[
Although the hyperparameters with the highest validation score are often preferred, model complexity should also be taken into consideration. This is why the number of nodes is displayed.

In this #NormalTok("iris"); example, the dataset is very small and the differences between validation scores are negligible. In such situations, a slightly simpler tree is often preferred because it is more interpretable and potentially more stable while achieving similar predictive performance.

In larger datasets, small differences in validation scores are often more meaningful, so predictive performance may be prioritized more heavily.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Example 2: Regression with the #NormalTok("diabetes"); dataset
<example-2-regression-with-the-diabetes-dataset>
We now look at a regression example. The #NormalTok("diabetes"); dataset uses 10 baseline variables to predict a quantitative measure of disease progression one year after baseline. More information can be found in the #NormalTok("sklearn"); #link(label("diabetes-dataset)"))[documentation] and the original diabetes dataset #link("(https://www4.stat.ncsu.edu/~boos/var.select/diabetes.html)")[description].

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_diabetes");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("X, y ");#OperatorTok("=");#NormalTok(" load_diabetes(return_X_y");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(X, y, test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
The overall workflow is similar to the #NormalTok("iris"); example. In this example, we choose to use cross-validation instead of a single validation split in order to obtain a more stable estimate of model performance. This is not specific to regression trees; either approach can be used for both classification and regression problems.

We first create a temporary tree to compute the critical #NormalTok("ccp_alpha"); values. The method #NormalTok("cost_complexity_pruning_path()"); internally grows a tree in order to compute the effective pruning path, although the estimator itself is not stored as a fitted model.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeRegressor");],
[],
[#NormalTok("base_tree ");#OperatorTok("=");#NormalTok(" DecisionTreeRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#NormalTok("path ");#OperatorTok("=");#NormalTok(" base_tree.cost_complexity_pruning_path(X_train, y_train)");],
[#NormalTok("ccp_alphas ");#OperatorTok("=");#NormalTok(" path.ccp_alphas[:");#OperatorTok("-");#DecValTok("1");#NormalTok("]");],));
]
This follows the classical CART pruning strategy:

+ Grow a large tree.
+ Compute the pruning path.
+ Use validation or cross-validation to select the final subtree.

Now we run #NormalTok("GridSearchCV"); over these #NormalTok("ccp_alpha"); values. We use $R^2$ as the model metric in this example.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" r2_score");],
[],
[#NormalTok("params ");#OperatorTok("=");#NormalTok(" param_grid ");#OperatorTok("=");#NormalTok(" {");#StringTok("\"ccp_alpha\"");#NormalTok(": ccp_alphas}");],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    DecisionTreeRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("), param_grid");#OperatorTok("=");#NormalTok("params, scoring");#OperatorTok("=");#StringTok("\"r2\"");],
[#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[],
[#NormalTok("best_tree ");#OperatorTok("=");#NormalTok(" grid.best_estimator_");],
[],
[#NormalTok("y_pred_train ");#OperatorTok("=");#NormalTok(" best_tree.predict(X_train)");],
[#NormalTok("y_pred_test ");#OperatorTok("=");#NormalTok(" best_tree.predict(X_test)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Best ccp_alpha: ");#SpecialCharTok("{");#NormalTok("grid");#SpecialCharTok(".");#NormalTok("best_params_[");#StringTok("'ccp_alpha'");#NormalTok("]");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Training R^2: ");#SpecialCharTok("{");#NormalTok("r2_score(y_train, y_pred_train)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Testing R^2: ");#SpecialCharTok("{");#NormalTok("r2_score(y_test, y_pred_test)");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Best ccp_alpha: 105.18472145590351");],
[#NormalTok("Training R^2: 0.5347863093947497");],
[#NormalTok("Testing R^2: 0.1922738375305083");],));
]
]
We can visualize the cross-validation curve. #NormalTok("GridSearchCV"); records validation scores, but it does not automatically record tree complexity measures such as the number of nodes. Therefore, if we want to display the complexity curve, we need to refit the models for the same #NormalTok("ccp_alpha"); values and record their node counts.

#Skylighting(([#NormalTok("cv_score ");#OperatorTok("=");#NormalTok(" grid.cv_results_[");#StringTok("\"mean_test_score\"");#NormalTok("]");],
[],
[#NormalTok("node_counts ");#OperatorTok("=");#NormalTok(" []");],
[#ControlFlowTok("for");#NormalTok(" ccp_alpha ");#KeywordTok("in");#NormalTok(" ccp_alphas:");],
[#NormalTok("    tree ");#OperatorTok("=");#NormalTok(" DecisionTreeRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", ccp_alpha");#OperatorTok("=");#NormalTok("ccp_alpha)");],
[#NormalTok("    tree.fit(X_train, y_train)");],
[#NormalTok("    node_counts.append(tree.tree_.node_count)");],
[],
[#NormalTok("best_alpha ");#OperatorTok("=");#NormalTok(" grid.best_params_[");#StringTok("\"ccp_alpha\"");#NormalTok("]");],
[],
[#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("2");#NormalTok(", ");#DecValTok("1");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(", ");#DecValTok("7");#NormalTok("), sharex");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].plot(ccp_alphas, node_counts, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", drawstyle");#OperatorTok("=");#StringTok("\"steps-post\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].plot(ccp_alphas, cv_score, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(", drawstyle");#OperatorTok("=");#StringTok("\"steps-post\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"CV score\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].axvline(best_alpha, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best ccp_alpha\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].axvline(best_alpha, color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best ccp_alpha\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_xlabel(");#StringTok("\"ccp_alpha\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].set_ylabel(");#StringTok("\"number of nodes\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_ylabel(");#StringTok("\"CV $R^2$\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].legend()");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].legend(loc");#OperatorTok("=");#StringTok("\"lower left\"");#NormalTok(")");],));
#box(image("contents\\2/tree_files/figure-typst/cell-16-output-1.svg"))

From the plot, our selected #NormalTok("ccp_alpha");=np.float64(105.18472145590351) is reasonable since it gives a relative strong cross-validation score without producing an unnecessarily large tree.

#block[
#callout(
body: 
[
A single regression tree often has unstable predictive performance on moderate-sized noisy datasets. Therefore, the test $R^2$ may not look high in this example. This is one reason why ensemble methods such as random forests and boosting are often preferred in practice.

]
, 
title: 
[
Warning
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
= Bagging and Random Forests
<bagging-and-random-forests>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
In earlier chapters we studied single decision trees. A tree is flexible because it can capture nonlinear relationships and interactions without specifying them in advance. However, a single tree is also unstable. A small change in the training data may produce a very different tree, especially when the tree is grown deeply.

Bagging and random forests are ensemble methods designed to reduce this instability.

The central idea is:

#quote(block: true)[
Instead of trusting one unstable tree, build many unstable trees and average them.
]

This chapter first discusses bagging. Random forests will then be introduced as an improvement of bagging. Since bagging and random forests use almost the same aggregation idea for regression and classification, we will mainly use regression notation. For classification, averages are usually replaced by majority vote or averaged class probabilities.

== Ensemble Averaging
<ensemble-averaging>
Suppose we observe training data

$ { \( x_i \, y_i \) }_(i = 1)^n \, quad x_i in bb(R)^p \, quad y_i in bb(R) . $

An ensemble combines many fitted models

$ hat(f)_1 \, hat(f)_2 \, dots.h \, hat(f)_B $

into one final predictor. For regression, the simplest ensemble average is

$ hat(f)_(upright("ens")) \( x \) = 1 / B sum_(b = 1)^B hat(f)_b \( x \) . $

Each individual model may be noisy. However, the average can be much more stable.

To see why, suppose each $hat(f)_b \( x \)$ has variance $sigma^2$, and suppose for a moment that the fitted models are independent. Then

$ "Var" (1 / B sum_(b = 1)^B hat(f)_b \( x \)) = sigma^2 / B . $

Thus averaging can greatly reduce variance.

In practice, the fitted models are not independent. If the pairwise correlation between two fitted models is approximately $rho$, then

Click to expand.
$ "Corr" \( hat(f)_i \( x \) \, hat(f)_j \( x \) \) approx rho \, #h(2em) i eq.not j . $

Then

$ "Cov" \( hat(f)_i \( x \) \, hat(f)_j \( x \) \) = "Corr" \( hat(f)_i \( x \) \, hat(f)_j \( x \) \) sqrt("Var" \( hat(f)_i \( x \) \) "Var" \( hat(f)_j \( x \) \)) approx rho sigma^2 . $

Therefore,

$ "Var" (1 / B sum_(b = 1)^B hat(f)_b \( x \)) & = 1 / B^2 [sum_(b = 1)^B "Var" \( hat(f)_b \( x \) \) + sum_(i eq.not j) "Cov" \( hat(f)_i \( x \) \, hat(f)_j \( x \) \)]\
 & approx 1 / B^2 [B sigma^2 + B \( B - 1 \) rho sigma^2]\
 & = sigma^2 [1 / B + frac(B - 1, B) rho]\
 & = rho sigma^2 + frac(1 - rho, B) sigma^2 . $

Then

$ "Var" (1 / B sum_(b = 1)^B hat(f)_b \( x \)) approx rho sigma^2 + frac(1 - rho, B) sigma^2 . $

This formula is very important. Increasing $B$ reduces the second term, but the first term remains. Therefore, if the individual trees are highly correlated, averaging has limited benefit.

== Bagging
<bagging>
Bagging is short for bootstrap aggregation.

Assume the original training set has $n$ data. A bootstrap sample is a sample drawn from the original training data with replacement. Each bootstrap sample has size $n$, but because sampling is done with replacement, some observations appear more than once and some observations do not appear at all.

Let $Z = { \( x_1 \, y_1 \) \, dots.h \, \( x_n \, y_n \) }$ be the original training set. Bagging constructs bootstrap samples $Z^(* 1) \, Z^(* 2) \, dots.h \, Z^(* B)$. For each bootstrap sample $Z^(* b)$, we fit a model $hat(f)_b \( x \)$. The bagged regression estimate is then

$ hat(f)_(upright("bag")) \( x \) = 1 / B sum_(b = 1)^B hat(f)_b \( x \) . $

For classification, the final prediction is usually based on majority vote:

$ hat(G)_(upright("bag")) \( x \) = "mode" { hat(G)_1 \( x \) \, dots.h \, hat(G)_B \( x \) } . $

Equivalently, we may average estimated class probabilities and choose the class with the largest average probability.

#block[
#callout(
body: 
[
Bagging is useful when the base learner is unstable. A decision tree is a typical unstable learner. Different bootstrap samples lead to different trees, because each tree sees a slightly different version of the data.

For a decision tree, bagging usually uses large trees rather than heavily pruned trees. The reason is that a large tree has low bias but high variance. Bagging is designed to reduce variance, so it is natural to start with a flexible base learner.

A single deep tree usually has low bias and high variance. Bagging keeps the low bias and reduces the variance by averaging many deep trees.

]
, 
title: 
[
Bias-variance view
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Although bagging is most commonly applied to decision trees, it can also be used with other types of models.

]
, 
title: 
[
Bagging estimators
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
=== Out-of-Bag Error
<out-of-bag-error>
Although a bootstrap sample has size $n$, it does not contain all $n$ observations.

#definition(title: [Out-of-bag observations])[
Each bootstrap sample contains about $63.2 %$ of the original observations as distinct observations. The remaining observations are called #strong[out-of-bag] (OOB) observations for that bootstrap sample.

Click to expand.
For a fixed observation $i$, the probability that it is not selected in one draw is

$ 1 - 1 / n . $

The probability that it is never selected in $n$ draws is

$ (1 - 1 / n)^n . $

When $n$ is large,

$ (1 - 1 / n)^n arrow.r e^(- 1) approx 0.368 . $

Therefore, the probability that observation $i$ appears at least once is approximately

$ 1 - e^(- 1) approx 0.632 \, $ and it is the expected proportion of distinct observations in a sample.

] <def->
The OOB observations give a natural way to estimate prediction error.

For observation $i$, consider only the trees for which observation $i$ was out-of-bag. Average those trees to get an OOB prediction:

$ hat(f)_(upright("OOB") \, i) = frac(1, \| B_i \|) sum_(b in B_i) hat(f)_b \( x_i \) \, $

where $B_i$ is the set of trees that did not use observation $i$ in their bootstrap sample.

The OOB mean squared error is

$ "MSE"_(upright("OOB")) = 1 / n sum_(i = 1)^n (y_i - hat(f)_(upright("OOB") \, i))^2 . $

All other metrics have OOB versions in the straightforward way.

OOB error is useful because it behaves like an internal validation estimate. We do not need to set aside a separate validation set just to estimate the error of the bagged model. Therefore, for bagging, in addition to single-split validation and cross-validation, we can also use OOB validation to tune hyperparameters.

== Random Forests
<random-forests>
Random forests are a modification of bagging for decision trees. In addition to the diversity by sampling observations from Bagging, Random forests create additional diversity by sampling features during tree construction.

The random forest algorithm for regression is:

+ Draw a bootstrap sample from the training data.
+ Grow a large regression tree on this bootstrap sample.
+ #strong[At each split, randomly choose $m$ predictors from the full set of $p$ predictors.]
+ #strong[Find the best split only among those $m$ predictors.]
+ Repeat this process for $B$ trees.
+ Average the predictions.

The final random forest regressor is

$ hat(f)_(upright("RF")) \( x \) = 1 / B sum_(b = 1)^B hat(f)_b \( x \) . $

The formula looks the same as bagging. The difference is how the trees are grown.

The key difference from Bagging(Trees) is the Step 3 and 4. In ordinary bagging, all predictors are available at every split. If there is one very strong predictor, many trees may split on that same predictor near the top of the tree. As a result, the trees become similar.

Similar trees are highly correlated. From the variance formula,

$ rho sigma^2 + frac(1 - rho, B) sigma^2 \, $

we know that high correlation limits the benefit of averaging.

Now random forests reduce this issue by forcing each split to consider only a random subset of predictors. This prevents the strongest predictors from dominating every tree. The trees become less correlated, and averaging becomes more effective.

=== #NormalTok("max_features");
<max_features>
How many predictors are considered at each split? In #NormalTok("sklearn");, this is controlled by #NormalTok("max_features");. This is a very important hyperparameter because it affects the correlations between trees.

Large #NormalTok("max_features"); means each tree can choose from many predictors. Individual trees may become stronger, but the trees may also become more similar to each other.

Small #NormalTok("max_features"); forces trees to explore different predictors. This usually decreases the correlations between trees, but each individual tree may become weaker.

Thus #NormalTok("max_features"); controls an important tradeoff between tree strength and tree correlation.

Common traditional choices are:

- for classification, #NormalTok("max_features");$= sqrt(p)$
- for regression, #NormalTok("max_features");$= p \/ 3$

These recommendations originated from the original Random Forest literature @breiman2001random and later became popular defaults in many software implementations @hastie2009elements. They are mainly based on empirical experience and the general intuition that:

- classification forests often benefit more from tree diversity
- regression forests often benefit more from stronger individual trees

In modern practice, however, #NormalTok("max_features"); is usually treated as a tuning hyperparameter and is commonly selected using validation or cross-validation.

=== Random Forest as Adaptive Local Averaging
<random-forest-as-adaptive-local-averaging>
A random forest can also be viewed as a data-adaptive local averaging method.

For one tree, two points are close if they fall in the same terminal node. Let

$ I_b \( x \, x_i \) = cases(delim: "{", 1 \, & upright(" if ") x upright(" and ") x_i upright(" are in the same leaf of tree ") b \,, 0 \, & upright(" otherwise") .) $

Across the whole forest, define the similarity

$ K_(upright("RF")) \( x \, x_i \) = 1 / B sum_(b = 1)^B I_b \( x \, x_i \) . $

This measures the proportion of trees in which $x$ and $x_i$ fall into the same terminal node. The quantity $K_(upright("RF")) \( x \, x_i \)$ can be interpreted as a data-adaptive similarity measure between $x$ and $x_i$.

The random forest prediction can be written as a weighted average

$ hat(f)_(upright("RF")) \( x \) = sum_(i = 1)^n w_i \( x \) y_i \, $

where observations that frequently share terminal nodes with $x$ receive larger weights.

More details about the adaptive nearest-neighbor interpretation of random forests can be found in #cite(<Lin2006>, form: "prose") and #cite(<hastie2009elements>, form: "prose").

#block[
#callout(
body: 
[
The adaptive-neighbor interpretation helps explain why random forests often perform much better than classical distance-based methods such as KNN in complex datasets.

In KNN, neighborhoods are determined by a fixed geometric distance. In contrast, random forests learn the neighborhood structure directly from the data through recursive splitting. Two observations are considered close if the forest repeatedly places them into the same terminal nodes, so the similarity automatically adapts to the importance of variables and their relationships with the response variable.

As a result, the neighborhood automatically adapts to:

- important variables
- interaction effects
- nonlinear structures
- local heterogeneity of the feature space

This viewpoint also provides intuition for why random forests are often robust in high-dimensional settings. Instead of relying on a global distance metric, the forest constructs many local data-dependent neighborhoods and averages over them.

From a theoretical perspective, this interpretation connects random forests to classical nonparametric smoothing methods such as KNN and kernel regression, helping explain random forests using the broader language of statistical learning theory.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Feature Importance
<feature-importance>
There are two commonly used measures of feature importance. We briefly discuss them here. More detailed examples and implementations can be found in the #link("https://scikit-learn.org/stable/auto_examples/inspection/plot_permutation_importance.html")[scikit-learn documentation].

==== Mean Decrease in Impurity
<mean-decrease-in-impurity>
One common measure is impurity-based importance, also called Mean Decrease in Impurity (MDI). This importance measure is specific to tree-based methods because it depends directly on the tree splitting process.

Recall that when building a tree, each split is selected to reduce a splitting impurity (or loss), such as:

- squared error for regression
- Gini impurity for classification

Impurity-based importance measures how much a variable decreases the splitting impurity across all splits in all trees. Variables that frequently produce large impurity reductions receive larger importance values.

For a single tree, the feature importance is simply the total impurity reduction contributed by that variable across all splits in the tree. However, because a single decision tree is often unstable and has high variance, these importance values may vary substantially from one tree to another. In bagging and Random Forests, the importance values are averaged across many trees, producing a much more stable and reliable measure of variable importance.

==== Permutation importance
<permutation-importance>
Another common measure is permutation importance. Unlike impurity-based importance, permutation importance is a general model-agnostic method and is not specific to trees or Random Forests.

The basic idea is:

+ Measure prediction error on validation data.
+ Randomly permute one predictor.
+ Measure prediction error again.

Permuting a predictor destroys the relationship between that predictor and the response while keeping the marginal distribution unchanged. If permuting a predictor substantially worsens predictive performance, then the model strongly relies on that predictor, indicating high importance.

Permutation importance is often easier to interpret because it is directly tied to predictive performance rather than the internal structure of the model.

#block[
#callout(
body: 
[
The two methods answer different questions:

- MDI explains how much the model used a variable during training.
- Permutation importance measures how much the model depends on that variable for prediction.

In general, if the main goal is to understand predictive performance and generalization, permutation importance is usually more relevant. However, MDI is much faster to compute because it is obtained directly during training. This advantage becomes especially important when the dataset contains many features or when the model is very large.

In many practical situations, MDI and permutation importance may produce similar rankings of variables. In addition, MDI can also help us investigate the internal structure of the model by showing how frequently and how effectively variables are used for splitting.

]
, 
title: 
[
MDI vs Permutation Importance
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Continuous predictors, predictors with many possible split points, or high-cardinality categorical variables may have more opportunities to create impurity reductions during splitting. Therefore, MDI may favor these variables.

]
, 
title: 
[
Limitations of MDI
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
When there are redundant features or highly correlated predictors, permuting one variable may not substantially reduce predictive performance because other correlated variables can still provide similar information. As a result, permutation importance may underestimate the importance of correlated predictors.

]
, 
title: 
[
Limitations of Permutation Importance
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Different Types of Randomization in Tree Ensembles
<different-types-of-randomization-in-tree-ensembles>
One of the main ideas behind ensemble tree methods is to introduce randomness in order to reduce variance. However, there are many different ways to introduce randomness. Different methods randomize different parts of the tree-building process.

The general tradeoff is:

- more randomness usually decreases variance
- but too much randomness may increase bias

The goal is therefore to make trees different while still keeping each tree reasonably strong.

=== \(Almost) No randomness: Single Decision Tree
<almost-no-randomness-single-decision-tree>
A standard CART tree contains almost no randomness.

At each node:

+ all predictors are considered
+ all candidate split points are searched
+ the best split is selected greedily

As a result:

- trees are highly adaptive
- trees usually have low bias
- but trees often have very high variance

Small changes in the training data may completely change the structure of the tree.

In reality, there is still a small amount of randomness in CART. For example, when multiple features produce identical impurity reductions, the algorithm may randomly choose among them.

In practice, in #NormalTok("sklearn");, this is implemented partly by randomizing the order of features. The #NormalTok("random_state"); parameter controls this randomness.

=== Bootstrap Randomness: Bagging
<bootstrap-randomness-bagging>
Bagging introduces randomness through bootstrap resampling.

For each tree:

+ sample observations with replacement
+ grow a large tree using the bootstrap sample
+ aggregate all trees together

The splitting procedure itself is unchanged:

- all predictors are still considered
- the best split is still searched greedily

Therefore, bagging mainly creates diversity by changing the training data seen by each tree.

The individual trees are still strong learners, but averaging reduces variance.

=== Feature Randomness: Random Forest
<feature-randomness-random-forest>
Random Forest adds another layer of randomness. At each split:

+ randomly select a subset of predictors
+ search for the best split only among those predictors

This has several important effects:

- strong predictors cannot dominate every split
- trees become less correlated
- averaging becomes more effective

However, the split threshold is still optimized greedily. For a chosen predictor, Random Forest still searches all candidate split points.

A natural question is why not randomly choose a subset of predictors once for the entire tree. The reason is that this would usually create trees that are too weak.

Suppose an important predictor is excluded at the beginning. Then the entire tree loses access to that predictor forever.

Random Forest instead performs randomization locally:

- each node receives a new random subset of predictors
- important predictors still have many opportunities to appear
- trees remain reasonably strong

This creates a balance between tree strength and tree diversity.

=== Threshold Randomness: Extra Trees
<threshold-randomness-extra-trees>
Extra Trees (Extremely Randomized Trees) introduces even more randomness. At each split:

+ randomly choose a subset of predictors (similar to Random Forest)
+ randomly generate candidate split thresholds, typically one threshold for each selected predictor
+ select the best split among those randomly generated thresholds

Unlike Random Forest:

- the algorithm does not exhaustively search all candidate split points
- the split thresholds themselves are randomized

This additional randomness usually:

- further decreases correlation between trees
- further reduces variance
- slightly increases bias

== Bagging in Python
<bagging-in-python>
We now discuss implementation details in #NormalTok("sklearn");.

There are two main approaches.

+ Use #NormalTok("BaggingRegressor"); or #NormalTok("BaggingClassifier"); with a chosen base estimator.
+ Use #NormalTok("RandomForestRegressor"); or #NormalTok("RandomForestClassifier"); when the base estimator is a decision tree and we also want random feature selection.

In the intial demo, we will only talk about Classifier since it is very similar to Regressor. We will use the following generated dataset as the demo example.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" make_classification");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("X, y ");#OperatorTok("=");#NormalTok(" make_classification(");],
[#NormalTok("    n_samples");#OperatorTok("=");#DecValTok("1200");#NormalTok(",");],
[#NormalTok("    n_features");#OperatorTok("=");#DecValTok("10");#NormalTok(",");],
[#NormalTok("    n_informative");#OperatorTok("=");#DecValTok("3");#NormalTok(",");],
[#NormalTok("    n_redundant");#OperatorTok("=");#DecValTok("2");#NormalTok(",");],
[#NormalTok("    n_repeated");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_clusters_per_class");#OperatorTok("=");#DecValTok("3");#NormalTok(",");],
[#NormalTok("    flip_y");#OperatorTok("=");#FloatTok("0.03");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", stratify");#OperatorTok("=");#NormalTok("y");],
[#NormalTok(")");],));
]
=== Basic Bagging classifier
<basic-bagging-classifier>
The following code creates a bagged ensemble of regression trees.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" BaggingClassifier");],
[#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[],
[#NormalTok("bag ");#OperatorTok("=");#NormalTok(" BaggingClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("0");#NormalTok("),");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(",");],
[#NormalTok("    max_samples");#OperatorTok("=");#FloatTok("1.0");#NormalTok(",");],
[#NormalTok("    bootstrap");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok(")");],));
]
The important arguments are:

- #NormalTok("estimator");: the base model. For classical tree bagging, this is a decision tree.
- #NormalTok("n_estimators");: the number of bootstrap models.
- #NormalTok("max_samples");: the sample size used for each bootstrap sample.
- #NormalTok("bootstrap");: whether sampling is done with replacement. #NormalTok("True"); gives bagging; #NormalTok("False"); gives pasting.
- #NormalTok("oob_score");: whether to compute out-of-bag performance.

After creating the model, we use the same #NormalTok(".fit()"); and #NormalTok(".predict()"); and #NormalTok(".score()"); workflow as before.

#Skylighting(([#NormalTok("bag.fit(X_train, y_train)");],
[#NormalTok("bag.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.9138888888888889");],));
=== Random Forest Classifier
<random-forest-classifier>
A random forest classifier is similar, but the random feature selection is built in.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" RandomForestClassifier");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(",");],
[#NormalTok("    max_features");#OperatorTok("=");#FloatTok("1.0");#NormalTok(",");],
[#NormalTok("    bootstrap");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");],
[#NormalTok(")");],
[],
[#NormalTok("rf.fit(X_train, y_train)");],
[#NormalTok("rf.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.9138888888888889");],));
The most important additional argument is #NormalTok("max_features");.

For example:

#block[
#Skylighting(([#NormalTok("RandomForestClassifier(max_features");#OperatorTok("=");#FloatTok("1.0");#NormalTok(")");],
[#NormalTok("RandomForestClassifier(max_features");#OperatorTok("=");#StringTok("\"sqrt\"");#NormalTok(")");],
[#NormalTok("RandomForestClassifier(max_features");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],));
]
- #NormalTok("1.0");: consider all predictors at each split. In this case, it is reduced to a #NormalTok("BaggingRegressor");.
- #NormalTok("\"sqrt\"");: consider about $sqrt(p)$ predictors at each split.
- #NormalTok("0.5");: consider half of the predictors at each split.

When #NormalTok("max_features=1.0");, a random forest regressor is very close to bagging with decision trees. When #NormalTok("max_features"); is smaller, the trees become more decorrelated.

=== Useful Attributes
<useful-attributes>
After fitting a bagging or random forest model, several attributes are useful. This example shows random forest, but bagging also supports these attributes.

- #NormalTok(".estimators_"); stores the fitted trees, and we could indicate which tree we want to use by calling the index.

#Skylighting(([#NormalTok("rf.estimators_[");#DecValTok("0");#NormalTok("]");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=criterion,-%7B%22gini%22%2C%20%22entropy%22%2C%20%22log_loss%22%7D%2C%20default%3D%22gini%22")[criterion #text(fill: rgb("#000"))[criterion: {\"gini\", \"entropy\", \"log\_loss\"}, default=\"gini\" \
   \
  The function to measure the quality of a split. Supported criteria are \
  \"gini\" for the Gini impurity and \"log\_loss\" and \"entropy\" both for the \
  Shannon information gain, see :ref:\`tree\_mathematical\_formulation\`.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'gini\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=splitter,-%7B%22best%22%2C%20%22random%22%7D%2C%20default%3D%22best%22")[splitter #text(fill: rgb("#000"))[splitter: {\"best\", \"random\"}, default=\"best\" \
   \
  The strategy used to choose the split at each node. Supported \
  strategies are \"best\" to choose the best split and \"random\" to choose \
  the best random split.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'best\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_depth,-int%2C%20default%3DNone")[max\_depth #text(fill: rgb("#000"))[max\_depth: int, default=None \
   \
  The maximum depth of the tree. If None, then nodes are expanded until \
  all leaves are pure or until all leaves contain less than \
  min\_samples\_split samples.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_samples_split,-int%20or%20float%2C%20default%3D2")[min\_samples\_split #text(fill: rgb("#000"))[min\_samples\_split: int or float, default=2 \
   \
  The minimum number of samples required to split an internal node: \
   \
  \- If int, then consider \`min\_samples\_split\` as the minimum number. \
  \- If float, then \`min\_samples\_split\` is a fraction and \
  \`ceil(min\_samples\_split \* n\_samples)\` are the minimum \
  number of samples for each split. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 2],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_samples_leaf,-int%20or%20float%2C%20default%3D1")[min\_samples\_leaf #text(fill: rgb("#000"))[min\_samples\_leaf: int or float, default=1 \
   \
  The minimum number of samples required to be at a leaf node. \
  A split point at any depth will only be considered if it leaves at \
  least \`\`min\_samples\_leaf\`\` training samples in each of the left and \
  right branches. This may have the effect of smoothing the model, \
  especially in regression. \
   \
  \- If int, then consider \`min\_samples\_leaf\` as the minimum number. \
  \- If float, then \`min\_samples\_leaf\` is a fraction and \
  \`ceil(min\_samples\_leaf \* n\_samples)\` are the minimum \
  number of samples for each node. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_weight_fraction_leaf,-float%2C%20default%3D0.0")[min\_weight\_fraction\_leaf #text(fill: rgb("#000"))[min\_weight\_fraction\_leaf: float, default=0.0 \
   \
  The minimum weighted fraction of the sum total of weights (of all \
  the input samples) required to be at a leaf node. Samples have \
  equal weight when sample\_weight is not provided.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_features,-int%2C%20float%20or%20%7B%22sqrt%22%2C%20%22log2%22%7D%2C%20default%3DNone")[max\_features #text(fill: rgb("#000"))[max\_features: int, float or {\"sqrt\", \"log2\"}, default=None \
   \
  The number of features to consider when looking for the best split: \
   \
  \- If int, then consider \`max\_features\` features at each split. \
  \- If float, then \`max\_features\` is a fraction and \
  \`max(1, int(max\_features \* n\_features\_in\_))\` features are considered at \
  each split. \
  \- If \"sqrt\", then \`max\_features=sqrt(n\_features)\`. \
  \- If \"log2\", then \`max\_features=log2(n\_features)\`. \
  \- If None, then \`max\_features=n\_features\`. \
   \
  .. note:: \
   \
  The search for a split does not stop until at least one \
  valid partition of the node samples is found, even if it requires to \
  effectively inspect more than \`\`max\_features\`\` features.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 1.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=random_state,-int%2C%20RandomState%20instance%20or%20None%2C%20default%3DNone")[random\_state #text(fill: rgb("#000"))[random\_state: int, RandomState instance or None, default=None \
   \
  Controls the randomness of the estimator. The features are always \
  randomly permuted at each split, even if \`\`splitter\`\` is set to \
  \`\`\"best\"\`\`. When \`\`max\_features \< n\_features\`\`, the algorithm will \
  select \`\`max\_features\`\` at random at each split before finding the best \
  split among them. But the best found split may vary across different \
  runs, even if \`\`max\_features=n\_features\`\`. That is the case, if the \
  improvement of the criterion is identical for several splits and one \
  split has to be selected at random. To obtain a deterministic behaviour \
  during fitting, \`\`random\_state\`\` has to be fixed to an integer. \
  See :term:\`Glossary \` for details.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 209652396],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_leaf_nodes,-int%2C%20default%3DNone")[max\_leaf\_nodes #text(fill: rgb("#000"))[max\_leaf\_nodes: int, default=None \
   \
  Grow a tree with \`\`max\_leaf\_nodes\`\` in best-first fashion. \
  Best nodes are defined as relative reduction in impurity. \
  If None then unlimited number of leaf nodes.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_impurity_decrease,-float%2C%20default%3D0.0")[min\_impurity\_decrease #text(fill: rgb("#000"))[min\_impurity\_decrease: float, default=0.0 \
   \
  A node will be split if this split induces a decrease of the impurity \
  greater than or equal to this value. \
   \
  The weighted impurity decrease equation is the following:: \
   \
  N\_t / N \* (impurity - N\_t\_R / N\_t \* right\_impurity \
  \- N\_t\_L / N\_t \* left\_impurity) \
   \
  where \`\`N\`\` is the total number of samples, \`\`N\_t\`\` is the number of \
  samples at the current node, \`\`N\_t\_L\`\` is the number of samples in the \
  left child, and \`\`N\_t\_R\`\` is the number of samples in the right child. \
   \
  \`\`N\`\`, \`\`N\_t\`\`, \`\`N\_t\_R\`\` and \`\`N\_t\_L\`\` all refer to the weighted sum, \
  if \`\`sample\_weight\`\` is passed. \
   \
  .. versionadded:: 0.19]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=class_weight,-dict%2C%20list%20of%20dict%20or%20%22balanced%22%2C%20default%3DNone")[class\_weight #text(fill: rgb("#000"))[class\_weight: dict, list of dict or \"balanced\", default=None \
   \
  Weights associated with classes in the form \`\`{class\_label: weight}\`\`. \
  If None, all classes are supposed to have weight one. For \
  multi-output problems, a list of dicts can be provided in the same \
  order as the columns of y. \
   \
  Note that for multioutput (including multilabel) weights should be \
  defined for each class of every column in its own dict. For example, \
  for four-class multilabel classification weights should be \
  \[{0: 1, 1: 1}, {0: 1, 1: 5}, {0: 1, 1: 1}, {0: 1, 1: 1}\] instead of \
  \[{1:1}, {2:5}, {3:1}, {4:1}\]. \
   \
  The \"balanced\" mode uses the values of y to automatically adjust \
  weights inversely proportional to class frequencies in the input data \
  as \`\`n\_samples / (n\_classes \* np.bincount(y))\`\` \
   \
  For multi-output, the weights of each column of y will be multiplied. \
   \
  Note that these weights will be multiplied with sample\_weight (passed \
  through the fit method) if sample\_weight is specified.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=ccp_alpha,-non-negative%20float%2C%20default%3D0.0")[ccp\_alpha #text(fill: rgb("#000"))[ccp\_alpha: non-negative float, default=0.0 \
   \
  Complexity parameter used for Minimal Cost-Complexity Pruning. The \
  subtree with the largest cost complexity that is smaller than \
  \`\`ccp\_alpha\`\` will be chosen. By default, no pruning is performed. See \
  :ref:\`minimal\_cost\_complexity\_pruning\` for details. See \
  :ref:\`sphx\_glr\_auto\_examples\_tree\_plot\_cost\_complexity\_pruning.py\` \
  for an example of such pruning. \
   \
  .. versionadded:: 0.22]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=monotonic_cst,-array-like%20of%20int%20of%20shape%20%28n_features%29%2C%20default%3DNone")[monotonic\_cst #text(fill: rgb("#000"))[monotonic\_cst: array-like of int of shape (n\_features), default=None \
   \
  Indicates the monotonicity constraint to enforce on each feature. \
  \- 1: monotonic increase \
  \- 0: no constraint \
  \- -1: monotonic decrease \
   \
  If monotonic\_cst is None, no constraints are applied. \
   \
  Monotonicity constraints are not supported for: \
  \- multiclass classifications (i.e. when \`n\_classes \> 2\`), \
  \- multioutput classifications (i.e. when \`n\_outputs\_ \> 1\`), \
  \- classifications trained on data with missing values. \
   \
  The constraints hold over the probability of the positive class. \
   \
  Read more in the :ref:\`User Guide \`. \
   \
  .. versionadded:: 1.4]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
)
- #NormalTok(".oob_score_"); gives the OOB score if #NormalTok("oob_score=True");. For classification, #NormalTok("bag.oob_score_"); is the OOB accuracy. For regression, it is the OOB $R^2$ score.

#Skylighting(([#NormalTok("rf.oob_score_");],));
#Skylighting(([#NormalTok("0.888095238095238");],));
==== Feature importance
<feature-importance-1>
MDI can be directly computated using #NormalTok(".feature_importances_"); after the model is fitted.

#Skylighting(([#NormalTok("rf.feature_importances_");],));
#Skylighting(([#NormalTok("array([0.02767912, 0.05947287, 0.11152095, 0.02443874, 0.02509798,");],
[#NormalTok("       0.25352125, 0.02526593, 0.03385812, 0.26526717, 0.17387786])");],));
For permutation importance, we use #NormalTok("permutation_importance"); from #NormalTok("sklearn.inspection");.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.inspection ");#ImportTok("import");#NormalTok(" permutation_importance");],
[],
[#NormalTok("pi ");#OperatorTok("=");#NormalTok(" permutation_importance(rf, X_test, y_test, n_repeats");#OperatorTok("=");#DecValTok("30");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("pi.importances_mean");],));
#Skylighting(([#NormalTok("array([-5.27777778e-03,  1.12037037e-02,  8.38888889e-02,  9.25925926e-05,");],
[#NormalTok("        4.62962963e-04,  1.86111111e-01, -1.20370370e-03,  2.96296296e-03,");],
[#NormalTok("        2.05000000e-01,  9.92592593e-02])");],));
In this example you may see that the two are very similar to each other.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("importance_df ");#OperatorTok("=");#NormalTok(" pd.DataFrame(");],
[#NormalTok("    {");#StringTok("\"MDI\"");#NormalTok(": rf.feature_importances_, ");#StringTok("\"Permutation\"");#NormalTok(": pi.importances_mean}");],
[#NormalTok(")");],
[#NormalTok("importance_df.plot.barh(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("8");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"importance\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Feature Importance Comparison\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'Feature Importance Comparison')");],));
#block[
#box(image("contents\\2/rf_files/figure-typst/cell-11-output-2.svg"))

]
== Tuning Hyperparameters
<tuning-hyperparameters-1>
Bagging and random forests are usually easier to tune than boosting. Still, several parameters matter.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Parameter], [Main effect],),
  table.hline(),
  [#NormalTok("n_estimators");], [More trees reduce Monte Carlo variation, but increase computation.],
  [#NormalTok("max_features");], [Controls tree correlation. Smaller values create more randomness.],
  [#NormalTok("max_samples");], [Controls bootstrap sample size. Smaller values create more diversity.],
  [#NormalTok("min_samples_leaf");], [Controls smoothness of each tree. Larger values reduce overfitting.],
  [#NormalTok("max_depth");], [Limits tree depth. Often left as #NormalTok("None");, but can help noisy data.],
)
A practical tuning strategy is:

+ Choose a reasonably large #NormalTok("n_estimators"); (so it is highly possible to be stable).
+ Tune #NormalTok("max_features");, #NormalTok("min_samples_leaf");, #NormalTok("max_samples"); or #NormalTok("max_depth"); with cross-validation or OOB error.
+ Make #NormalTok("n_estimators"); smaller to find the smallest stable number.

#block[
#callout(
body: 
[
For bagging / random forests, #NormalTok("n_estimators"); is usually not a regularization parameter in the usual sense. Increasing the number of trees usually stabilizes the model rather than causing overfitting. The main cost is computation. Therefore when reading the score vs number of trees plot, we are not looking at the highest score, we are looking at when the score is stablizing.

]
, 
title: 
[
#NormalTok("n_estimators");
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
These two represent different things.

- #NormalTok("max_samples=1"); means that the max number of samples we choose is 1.
- #NormalTok("max_samples=1.0"); means that we want to choose all samples that the percent is 1.0=100%.

]
, 
title: 
[
#NormalTok("1"); and #NormalTok("1.0");
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Comparing to single tree/boosting, we tend to use larger trees in bagging. Therefore we don't need #NormalTok("ccp_alpha");, and we could use larger #NormalTok("max_depth"); and smaller #NormalTok("min_samples_leaf");.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
We could use oob score to tune hyperparameters. However we have to manually write the tuning code.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" RandomForestClassifier");],
[],
[#NormalTok("max_features_list ");#OperatorTok("=");#NormalTok(" [");#FloatTok("0.3");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#FloatTok("1.0");#NormalTok("]");],
[#NormalTok("best_score ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("-");#DecValTok("1");],
[#NormalTok("best_param ");#OperatorTok("=");#NormalTok(" ");#VariableTok("None");],
[],
[#ControlFlowTok("for");#NormalTok(" mf ");#KeywordTok("in");#NormalTok(" max_features_list:");],
[#NormalTok("    rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(");],
[#NormalTok("        n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(", max_features");#OperatorTok("=");#NormalTok("mf, oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok("    )");],
[#NormalTok("    rf.fit(X_train, y_train)");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" rf.oob_score_ ");#OperatorTok(">");#NormalTok(" best_score:");],
[#NormalTok("        best_score ");#OperatorTok("=");#NormalTok(" rf.oob_score_");],
[#NormalTok("        best_param ");#OperatorTok("=");#NormalTok(" mf");],
[],
[#BuiltInTok("print");#NormalTok("(best_param)");],));
#block[
#Skylighting(([#NormalTok("0.3");],));
]
]
]
, 
title: 
[
OOB validation
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
We could still use cross-validation to tune a random forest classifier.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" RandomForestClassifier");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_features\"");#NormalTok(": [");#FloatTok("0.3");#NormalTok(", ");#FloatTok("0.6");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_samples\"");#NormalTok(": [");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(rf, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[],
[#NormalTok("best_rf ");#OperatorTok("=");#NormalTok(" grid.best_estimator_");],
[#NormalTok("grid.best_params_");],));
#Skylighting(([#NormalTok("{'max_features': 0.3, 'max_samples': 0.8, 'min_samples_leaf': 1}");],));
]
, 
title: 
[
Cross-validation
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
If the dataset is large, a full grid can be slow. In that case, #NormalTok("RandomizedSearchCV"); is often a better choice. In this case, only a few random combinations will be searched. In the following example, we only search 30 combinations.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" RandomizedSearchCV");],
[#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" randint, uniform");],
[],
[#NormalTok("param_dist ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_features\"");#NormalTok(": uniform(");#FloatTok("0.2");#NormalTok(", ");#FloatTok("0.8");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"min_samples_leaf\"");#NormalTok(": randint(");#DecValTok("1");#NormalTok(", ");#DecValTok("20");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"max_samples\"");#NormalTok(": uniform(");#FloatTok("0.5");#NormalTok(", ");#FloatTok("0.5");#NormalTok("),");],
[#NormalTok("}");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("search ");#OperatorTok("=");#NormalTok(" RandomizedSearchCV(");],
[#NormalTok("    rf, param_distributions");#OperatorTok("=");#NormalTok("param_dist, n_iter");#OperatorTok("=");#DecValTok("30");#NormalTok(", cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok(")");],
[],
[#NormalTok("search.fit(X_train, y_train)");],
[#NormalTok("search.best_params_");],));
#Skylighting(([#NormalTok("{'max_features': np.float64(0.9220787804235238),");],
[#NormalTok(" 'max_samples': np.float64(0.7249749949556138),");],
[#NormalTok(" 'min_samples_leaf': 2}");],));
]
, 
title: 
[
Randomized Search
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== #NormalTok("n_jobs");
<n_jobs-1>
When we reach this stage, you may notice that training can become quite slow. This is expected because, in #NormalTok("GridSearchCV");, we need to evaluate many combinations of hyperparameters. For each combination, we may need to train many trees (due to bagging or Random Forests), and the entire process must be repeated multiple times because of cross-validation (for example, #NormalTok("cv=5");).

Although many models need to be trained, an important advantage is that these training tasks are largely independent. Therefore, they can often be trained simultaneously using multiple CPU cores.

In contrast, boosting methods that we will discuss later are fundamentally sequential. Each tree depends on the results of the previous trees, so the trees must be trained one after another. As a result, boosting methods are generally less parallelizable at the tree level.

#NormalTok("sklearn"); supports multi-core CPUs through the #NormalTok("n_jobs"); argument.

- #NormalTok("n_jobs=1"); means single-core execution
- #NormalTok("n_jobs=k"); uses exactly #NormalTok("k"); CPU cores
- #NormalTok("n_jobs=-1"); uses all available CPU cores
- #NormalTok("n_jobs=None"); uses the library default, which is currently equivalent to #NormalTok("1"); in most #NormalTok("sklearn"); functions

Many functions in #NormalTok("sklearn"); support this argument. For details, consult the official documentation for the specific function being used.

One important practical issue is nested parallelism. When multiple nested functions both support #NormalTok("n_jobs");, it is usually best to parallelize only the outermost function.

For example, #NormalTok("GridSearchCV(RandomForestClassifier(n_jobs=1), n_jobs=-1)"); is generally preferred over #NormalTok("GridSearchCV(RandomForestClassifier(n_jobs=-1), n_jobs=-1)"); because allowing both levels to parallelize simultaneously may create too many worker processes or threads, leading to excessive overhead and sometimes even slower performance.

#example(title: [time it])[
We first write a helper function to compute the runtime.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" time ");#ImportTok("import");#NormalTok(" perf_counter");],
[#ImportTok("from");#NormalTok(" contextlib ");#ImportTok("import");#NormalTok(" contextmanager");],
[],
[#AttributeTok("@contextmanager");],
[#KeywordTok("def");#NormalTok(" timer(name");#OperatorTok("=");#StringTok("\"runtime\"");#NormalTok("):");],
[#NormalTok("    start ");#OperatorTok("=");#NormalTok(" perf_counter()");],
[#NormalTok("    ");#ControlFlowTok("yield");],
[#NormalTok("    end ");#OperatorTok("=");#NormalTok(" perf_counter()");],
[],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"");#SpecialCharTok("{");#NormalTok("name");#SpecialCharTok("}");#SpecialStringTok(": ");#SpecialCharTok("{");#NormalTok("end ");#OperatorTok("-");#NormalTok(" start");#SpecialCharTok(":.4f}");#SpecialStringTok(" seconds\"");#NormalTok(")");],));
]
Then use it to test the time for different #NormalTok("n_jobs");.

#block[
#Skylighting(([#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_features\"");#NormalTok(": [");#FloatTok("0.3");#NormalTok(", ");#FloatTok("0.6");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_samples\"");#NormalTok(": [");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestClassifier(n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(rf, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#ControlFlowTok("with");#NormalTok(" timer(");#StringTok("\"n_jobs=-1\"");#NormalTok("):");],
[#NormalTok("    grid.fit(X_train, y_train)");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(rf, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[#ControlFlowTok("with");#NormalTok(" timer(");#StringTok("\"n_jobs=1\"");#NormalTok("):");],
[#NormalTok("    grid.fit(X_train, y_train)");],));
#block[
#Skylighting(([#NormalTok("n_jobs=-1: 18.5742 seconds");],
[#NormalTok("n_jobs=1: 62.7026 seconds");],));
]
]
] <exm->
== Example: Diabetes dataset
<example-diabetes-dataset>
We now use the diabetes regression dataset from #NormalTok("sklearn");. In order to compare results using trees, we use the same split with #NormalTok("random_state=1");.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_diabetes");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" mean_squared_error, r2_score");],
[],
[#NormalTok("X, y ");#OperatorTok("=");#NormalTok(" load_diabetes(return_X_y");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(X, y, test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
We compare three models:

+ a single regression tree,
+ bagging with regression trees,
+ a random forest.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeRegressor");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" BaggingRegressor, RandomForestRegressor");],
[],
[#NormalTok("tree ");#OperatorTok("=");#NormalTok(" DecisionTreeRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", ccp_alpha");#OperatorTok("=");#FloatTok("105.185");#NormalTok(")");],
[],
[#NormalTok("bag ");#OperatorTok("=");#NormalTok(" BaggingRegressor(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(",");],
[#NormalTok("    oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("rf ");#OperatorTok("=");#NormalTok(" RandomForestRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(",");],
[#NormalTok("    max_features");#OperatorTok("=");#StringTok("\"sqrt\"");#NormalTok(",");],
[#NormalTok("    oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],));
]
#Skylighting(([#NormalTok("tree.fit(X_train, y_train)");],
[#NormalTok("tree.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.1922738375305083");],));
#Skylighting(([#NormalTok("bag.fit(X_train, y_train)");],
[#NormalTok("bag.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.2951908085625511");],));
#Skylighting(([#NormalTok("rf.fit(X_train, y_train)");],
[#NormalTok("rf.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.3555401846697034");],));
The single tree is expected to be unstable. Bagging and random forests usually improve test performance by averaging many trees.

For the bagging and random forest models, we can also check OOB performance.

#Skylighting(([#NormalTok("bag.oob_score_");],));
#Skylighting(([#NormalTok("0.4567923788468702");],));
#Skylighting(([#NormalTok("rf.oob_score_");],));
#Skylighting(([#NormalTok("0.47245609860472904");],));
OOB $R^2$ gives an internal estimate of predictive performance based only on the training data.

=== Tuning the Random Forest
<tuning-the-random-forest>
We showed #NormalTok("Bagging"); in the previous section. Since it overlaps with #NormalTok("RandomForest");, we will only focus on the Random Forest model in this section. We first tune #NormalTok("max_features");, #NormalTok("min_samples_leaf");, and #NormalTok("max_samples"); by cross-validation, with a relative small number of estimators.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[],
[#NormalTok("rf_base ");#OperatorTok("=");#NormalTok(" RandomForestRegressor(n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_features\"");#NormalTok(": [");#StringTok("\"sqrt\"");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_samples\"");#NormalTok(": [");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.8");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(rf_base, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Best parameters: ");#SpecialCharTok("{");#NormalTok("grid");#SpecialCharTok(".");#NormalTok("best_params_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Best CV R^2: ");#SpecialCharTok("{");#NormalTok("grid");#SpecialCharTok(".");#NormalTok("best_score_");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Best parameters: {'max_features': 'sqrt', 'max_samples': 1.0, 'min_samples_leaf': 5}");],
[#NormalTok("Best CV R^2: 0.45220837115313606");],));
]
]
Now evaluate the tuned model on the test set.

#Skylighting(([#NormalTok("grid.best_estimator_.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.3777186499485139");],));
=== Find the Number of Trees
<find-the-number-of-trees>
The number of trees controls how stable the ensemble average is. The following code fits forests with different numbers of trees and records OOB performance.

#Skylighting(([#NormalTok("tree_counts ");#OperatorTok("=");#NormalTok(" [");#DecValTok("10");#NormalTok(", ");#DecValTok("25");#NormalTok(", ");#DecValTok("50");#NormalTok(", ");#DecValTok("100");#NormalTok(", ");#DecValTok("200");#NormalTok(", ");#DecValTok("300");#NormalTok(", ");#DecValTok("400");#NormalTok(", ");#DecValTok("800");#NormalTok("]");],
[#NormalTok("oob_scores ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("test_r2 ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" n_trees ");#KeywordTok("in");#NormalTok(" tree_counts:");],
[#NormalTok("    model ");#OperatorTok("=");#NormalTok(" RandomForestRegressor(");],
[#NormalTok("        n_estimators");#OperatorTok("=");#NormalTok("n_trees,");],
[#NormalTok("        max_features");#OperatorTok("=");#StringTok("\"sqrt\"");#NormalTok(",");],
[#NormalTok("        max_samples");#OperatorTok("=");#FloatTok("1.0");#NormalTok(",");],
[#NormalTok("        min_samples_leaf");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("        oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("        random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok("        n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    )");],
[#NormalTok("    model.fit(X_train, y_train)");],
[#NormalTok("    oob_scores.append(model.oob_score_)");],
[#NormalTok("    test_r2.append(model.score(X_test, y_test))");],
[],
[#NormalTok("fig, ax ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("11");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].plot(tree_counts, oob_scores, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].set_xlabel(");#StringTok("\"number of trees\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].set_ylabel(");#StringTok("\"OOB R^2\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"OOB score\"");#NormalTok(")");],
[],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].plot(tree_counts, test_r2, marker");#OperatorTok("=");#StringTok("\"o\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_xlabel(");#StringTok("\"number of trees\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_ylabel(");#StringTok("\"test R^2\"");#NormalTok(")");],
[#NormalTok("ax[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"Validation score (using test set)\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\2/rf_files/figure-typst/cell-26-output-1.svg"))

As mentioned previously, when reading these two plots, it is important not to focus on the single highest point. Instead, we look for the point where the curve becomes stable and nearly flat. In this example, around 200 trees appears to be a reasonable choice.

Therefore our best model so far is

#Skylighting(([#NormalTok("best_rf ");#OperatorTok("=");#NormalTok(" RandomForestRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("200");#NormalTok(",");],
[#NormalTok("    max_features");#OperatorTok("=");#StringTok("\"sqrt\"");#NormalTok(",");],
[#NormalTok("    max_samples");#OperatorTok("=");#FloatTok("1.0");#NormalTok(",");],
[#NormalTok("    min_samples_leaf");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    oob_score");#OperatorTok("=");#VariableTok("True");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok(")");],
[#NormalTok("best_rf.fit(X_train, y_train)");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=n_estimators,-int%2C%20default%3D100")[n\_estimators #text(fill: rgb("#000"))[n\_estimators: int, default=100 \
   \
  The number of trees in the forest. \
   \
  .. versionchanged:: 0.22 \
  The default value of \`\`n\_estimators\`\` changed from 10 to 100 \
  in 0.22.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 200],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=criterion,-%7B%22squared_error%22%2C%20%22absolute_error%22%2C%20%22friedman_mse%22%2C%20%22poisson%22%7D%2C%20%20%20%20%20%20%20%20%20%20%20%20%20default%3D%22squared_error%22")[criterion #text(fill: rgb("#000"))[criterion: {\"squared\_error\", \"absolute\_error\", \"friedman\_mse\", \"poisson\"}, default=\"squared\_error\" \
   \
  The function to measure the quality of a split. Supported criteria \
  are \"squared\_error\" for the mean squared error, which is equal to \
  variance reduction as feature selection criterion and minimizes the L2 \
  loss using the mean of each terminal node, \"friedman\_mse\", which uses \
  mean squared error with Friedman\'s improvement score for potential \
  splits, \"absolute\_error\" for the mean absolute error, which minimizes \
  the L1 loss using the median of each terminal node, and \"poisson\" which \
  uses reduction in Poisson deviance to find splits. \
  Training using \"absolute\_error\" is significantly slower \
  than when using \"squared\_error\". \
   \
  .. versionadded:: 0.18 \
  Mean Absolute Error (MAE) criterion. \
   \
  .. versionadded:: 1.0 \
  Poisson criterion.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'squared\_error\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=max_depth,-int%2C%20default%3DNone")[max\_depth #text(fill: rgb("#000"))[max\_depth: int, default=None \
   \
  The maximum depth of the tree. If None, then nodes are expanded until \
  all leaves are pure or until all leaves contain less than \
  min\_samples\_split samples.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=min_samples_split,-int%20or%20float%2C%20default%3D2")[min\_samples\_split #text(fill: rgb("#000"))[min\_samples\_split: int or float, default=2 \
   \
  The minimum number of samples required to split an internal node: \
   \
  \- If int, then consider \`min\_samples\_split\` as the minimum number. \
  \- If float, then \`min\_samples\_split\` is a fraction and \
  \`ceil(min\_samples\_split \* n\_samples)\` are the minimum \
  number of samples for each split. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 2],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=min_samples_leaf,-int%20or%20float%2C%20default%3D1")[min\_samples\_leaf #text(fill: rgb("#000"))[min\_samples\_leaf: int or float, default=1 \
   \
  The minimum number of samples required to be at a leaf node. \
  A split point at any depth will only be considered if it leaves at \
  least \`\`min\_samples\_leaf\`\` training samples in each of the left and \
  right branches. This may have the effect of smoothing the model, \
  especially in regression. \
   \
  \- If int, then consider \`min\_samples\_leaf\` as the minimum number. \
  \- If float, then \`min\_samples\_leaf\` is a fraction and \
  \`ceil(min\_samples\_leaf \* n\_samples)\` are the minimum \
  number of samples for each node. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 5],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=min_weight_fraction_leaf,-float%2C%20default%3D0.0")[min\_weight\_fraction\_leaf #text(fill: rgb("#000"))[min\_weight\_fraction\_leaf: float, default=0.0 \
   \
  The minimum weighted fraction of the sum total of weights (of all \
  the input samples) required to be at a leaf node. Samples have \
  equal weight when sample\_weight is not provided.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=max_features,-%7B%22sqrt%22%2C%20%22log2%22%2C%20None%7D%2C%20int%20or%20float%2C%20default%3D1.0")[max\_features #text(fill: rgb("#000"))[max\_features: {\"sqrt\", \"log2\", None}, int or float, default=1.0 \
   \
  The number of features to consider when looking for the best split: \
   \
  \- If int, then consider \`max\_features\` features at each split. \
  \- If float, then \`max\_features\` is a fraction and \
  \`max(1, int(max\_features \* n\_features\_in\_))\` features are considered at each \
  split. \
  \- If \"sqrt\", then \`max\_features=sqrt(n\_features)\`. \
  \- If \"log2\", then \`max\_features=log2(n\_features)\`. \
  \- If None or 1.0, then \`max\_features=n\_features\`. \
   \
  .. note:: \
  The default of 1.0 is equivalent to bagged trees and more \
  randomness can be achieved by setting smaller values, e.g. 0.3. \
   \
  .. versionchanged:: 1.1 \
  The default of \`max\_features\` changed from \`\"auto\"\` to 1.0. \
   \
  Note: the search for a split does not stop until at least one \
  valid partition of the node samples is found, even if it requires to \
  effectively inspect more than \`\`max\_features\`\` features.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); \'sqrt\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=max_leaf_nodes,-int%2C%20default%3DNone")[max\_leaf\_nodes #text(fill: rgb("#000"))[max\_leaf\_nodes: int, default=None \
   \
  Grow trees with \`\`max\_leaf\_nodes\`\` in best-first fashion. \
  Best nodes are defined as relative reduction in impurity. \
  If None then unlimited number of leaf nodes.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=min_impurity_decrease,-float%2C%20default%3D0.0")[min\_impurity\_decrease #text(fill: rgb("#000"))[min\_impurity\_decrease: float, default=0.0 \
   \
  A node will be split if this split induces a decrease of the impurity \
  greater than or equal to this value. \
   \
  The weighted impurity decrease equation is the following:: \
   \
  N\_t / N \* (impurity - N\_t\_R / N\_t \* right\_impurity \
  \- N\_t\_L / N\_t \* left\_impurity) \
   \
  where \`\`N\`\` is the total number of samples, \`\`N\_t\`\` is the number of \
  samples at the current node, \`\`N\_t\_L\`\` is the number of samples in the \
  left child, and \`\`N\_t\_R\`\` is the number of samples in the right child. \
   \
  \`\`N\`\`, \`\`N\_t\`\`, \`\`N\_t\_R\`\` and \`\`N\_t\_L\`\` all refer to the weighted sum, \
  if \`\`sample\_weight\`\` is passed. \
   \
  .. versionadded:: 0.19]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=bootstrap,-bool%2C%20default%3DTrue")[bootstrap #text(fill: rgb("#000"))[bootstrap: bool, default=True \
   \
  Whether bootstrap samples are used when building trees. If False, the \
  whole dataset is used to build each tree.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=oob_score,-bool%20or%20callable%2C%20default%3DFalse")[oob\_score #text(fill: rgb("#000"))[oob\_score: bool or callable, default=False \
   \
  Whether to use out-of-bag samples to estimate the generalization score. \
  By default, :func:\`\~sklearn.metrics.r2\_score\` is used. \
  Provide a callable with signature \`metric(y\_true, y\_pred)\` to use a \
  custom metric. Only available if \`bootstrap=True\`. \
   \
  For an illustration of out-of-bag (OOB) error estimation, see the example \
  :ref:\`sphx\_glr\_auto\_examples\_ensemble\_plot\_ensemble\_oob.py\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); True],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=n_jobs,-int%2C%20default%3DNone")[n\_jobs #text(fill: rgb("#000"))[n\_jobs: int, default=None \
   \
  The number of jobs to run in parallel. :meth:\`fit\`, :meth:\`predict\`, \
  :meth:\`decision\_path\` and :meth:\`apply\` are all parallelized over the \
  trees. \`\`None\`\` means 1 unless in a :obj:\`joblib.parallel\_backend\` \
  context. \`\`-1\`\` means using all processors. See :term:\`Glossary \
  \` for more details.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); -1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=random_state,-int%2C%20RandomState%20instance%20or%20None%2C%20default%3DNone")[random\_state #text(fill: rgb("#000"))[random\_state: int, RandomState instance or None, default=None \
   \
  Controls both the randomness of the bootstrapping of the samples used \
  when building trees (if \`\`bootstrap=True\`\`) and the sampling of the \
  features to consider when looking for the best split at each node \
  (if \`\`max\_features \< n\_features\`\`). \
  See :term:\`Glossary \` for details.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=verbose,-int%2C%20default%3D0")[verbose #text(fill: rgb("#000"))[verbose: int, default=0 \
   \
  Controls the verbosity when fitting and predicting.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=warm_start,-bool%2C%20default%3DFalse")[warm\_start #text(fill: rgb("#000"))[warm\_start: bool, default=False \
   \
  When set to \`\`True\`\`, reuse the solution of the previous call to fit \
  and add more estimators to the ensemble, otherwise, just fit a whole \
  new forest. See :term:\`Glossary \` and \
  :ref:\`tree\_ensemble\_warm\_start\` for details.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); False],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=ccp_alpha,-non-negative%20float%2C%20default%3D0.0")[ccp\_alpha #text(fill: rgb("#000"))[ccp\_alpha: non-negative float, default=0.0 \
   \
  Complexity parameter used for Minimal Cost-Complexity Pruning. The \
  subtree with the largest cost complexity that is smaller than \
  \`\`ccp\_alpha\`\` will be chosen. By default, no pruning is performed. See \
  :ref:\`minimal\_cost\_complexity\_pruning\` for details. See \
  :ref:\`sphx\_glr\_auto\_examples\_tree\_plot\_cost\_complexity\_pruning.py\` \
  for an example of such pruning. \
   \
  .. versionadded:: 0.22]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=max_samples,-int%20or%20float%2C%20default%3DNone")[max\_samples #text(fill: rgb("#000"))[max\_samples: int or float, default=None \
   \
  If bootstrap is True, the number of samples to draw from X \
  to train each base estimator. \
   \
  \- If None (default), then draw \`X.shape\[0\]\` samples. \
  \- If int, then draw \`max\_samples\` samples. \
  \- If float, then draw \`max(round(n\_samples \* max\_samples), 1)\` samples. Thus, \
  \`max\_samples\` should be in the interval \`(0.0, 1.0\]\`. \
   \
  .. versionadded:: 0.22]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 1.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestRegressor.html#:~:text=monotonic_cst,-array-like%20of%20int%20of%20shape%20%28n_features%29%2C%20default%3DNone")[monotonic\_cst #text(fill: rgb("#000"))[monotonic\_cst: array-like of int of shape (n\_features), default=None \
   \
  Indicates the monotonicity constraint to enforce on each feature. \
  \- 1: monotonically increasing \
  \- 0: no constraint \
  \- -1: monotonically decreasing \
   \
  If monotonic\_cst is None, no constraints are applied. \
   \
  Monotonicity constraints are not supported for: \
  \- multioutput regressions (i.e. when \`n\_outputs\_ \> 1\`), \
  \- regressions trained on data with missing values. \
   \
  Read more in the :ref:\`User Guide \`. \
   \
  .. versionadded:: 1.4]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
)
==== Variable Importance
<variable-importance>
We first examine impurity-based feature importance.

#Skylighting(([#NormalTok("importance ");#OperatorTok("=");#NormalTok(" pd.Series(best_rf.feature_importances_).sort_values(ascending");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("importance.plot(kind");#OperatorTok("=");#StringTok("\"barh\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"impurity-based importance\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Random Forest Feature Importance\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'Random Forest Feature Importance')");],));
#block[
#box(image("contents\\2/rf_files/figure-typst/cell-28-output-2.svg"))

]
These values measure how much each variable reduces prediction error inside the trees. They are useful for a quick summary, but they should not be treated as causal effects.

Permutation importance gives a more direct performance-based measure.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.inspection ");#ImportTok("import");#NormalTok(" permutation_importance");],
[],
[#NormalTok("perm ");#OperatorTok("=");#NormalTok(" permutation_importance(");],
[#NormalTok("    best_rf, X_test, y_test, n_repeats");#OperatorTok("=");#DecValTok("30");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok(")");],
[#NormalTok("perm_importance ");#OperatorTok("=");#NormalTok(" pd.Series(perm.importances_mean).sort_values(ascending");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("perm_importance.plot(kind");#OperatorTok("=");#StringTok("\"barh\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"decrease in R^2 after permutation\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Permutation Importance\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'Permutation Importance')");],));
#block[
#box(image("contents\\2/rf_files/figure-typst/cell-29-output-2.svg"))

]
If permuting a predictor substantially worsens predictions, then the fitted random forest relies on that predictor. If the importance is near zero, the predictor may not add much predictive information beyond the others.

From the two plots, feature 2 and 8 are the two most important features. If we go back to check the description of the dataset, they are #NormalTok("bmi: body mass index"); and #NormalTok("s5: ltg, possibly log of serum triglycerides level");.

= Boosting
<boosting>
#block[
\$\$
\\require{physics}
\\require{braket}
\$\$

$  $

\$\$

\$\$

$  $

$  $

]
Boosting is another ensemble method. Like bagging and random forests, it combines many trees into one model. The difference is how the trees are built.

Bagging and random forests build trees independently and then average them.

Boosting builds trees sequentially. Each new tree is trained to improve the current ensemble.

The central idea is:

#quote(block: true)[
Build many weak learners one at a time, and let each new learner focus on what the current model still gets wrong.
]

This chapter first discusses AdaBoost. AdaBoost is historically important and is the cleanest way to see the boosting idea. We then discuss the margin effect of AdaBoost and how to tune its hyperparameters. Finally, we discuss gradient boosting and use XGBoost as the main implementation example.

== AdaBoost
<adaboost>
AdaBoost (Adaptive Boosting) was introduced by Yoav Freund and Robert E. Schapire in 1995 #cite(<Freund1995>, form: "prose") as one of the first highly successful boosting algorithms. Their original work showed that many weak learners, each performing only slightly better than random guessing, could be combined into a highly accurate classifier. AdaBoost became a foundational method in statistical learning, and it strongly influenced the later development of modern boosting methods such as Gradient Boosting and XGBoost.

The original AdaBoost algorithm was proposed as a classification method. Regression extensions were developed later after the success of AdaBoost classifiers. In this course, we mainly study AdaBoost classification because it introduces the core ideas of boosting in a simple and historically important setting.

For regression problems, we will move on to gradient boosting methods, which have become the dominant boosting framework in modern machine learning.

To keep the notation simple, assume the response is binary:

$ y_i in { - 1 \, + 1 } . $

AdaBoost constructs a classifier of the form

$ F_M \( x \) = sum_(m = 1)^M alpha_m G_m \( x \) \, $

where:

- $G_m \( x \)$ is the $m$-th weak classifier,
- $alpha_m$ is the weight assigned to that classifier,
- $M$ is the number of boosting rounds.

The final prediction is

$ hat(G) \( x \) = "sign" { F_M \( x \) } . $

Thus AdaBoost is a weighted voting method. Classifiers with larger $alpha_m$ have more influence in the final vote.

=== Weak Learners
<weak-learners>
AdaBoost is built from weak learners.

A weak learner is a classifier that is only slightly better than random guessing. In tree-based AdaBoost, the most common weak learner is a decision stump, which is a tree with only one split.

In #NormalTok("sklearn");, a decision stump is created by

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[],
[#NormalTok("DecisionTreeClassifier(max_depth");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
A decision stump is extremely simple and usually underfits when used alone. One of the most surprising and important ideas behind AdaBoost is that by combining many such weak learners sequentially, the resulting ensemble can become a highly accurate and powerful model.

=== Weights of observations
<weights-of-observations>
In AdaBoost, there are two different types of weights.

- Estimator weights ($alpha_m$) determine how much influence each weak learner has in the final ensemble.
- Observation weights ($w_i^(\( m \))$) determine which training observations receive more attention when fitting the next learner.

During training, AdaBoost repeatedly updates the weights of the training observations. Observations that are difficult to classify receive larger weights, so future learners focus more on them.

To understand this process, we need to discuss how a decision tree is trained on a weighted dataset.

The main idea is very simple. In an ordinary dataset, quantities such as class frequencies and node sample counts are computed using the number of observations. For a weighted dataset, these counts are replaced by weighted counts, that is, by the sum of the observation weights.

For example, suppose a node contains observations with weights $w_1 \, w_2 \, dots.h \, w_n$. Then the effective sample size of the node becomes $sum_(i = 1)^n w_i$. Similarly, class proportions are computed using weighted proportions rather than ordinary proportions.

Therefore, training a decision tree on weighted data is conceptually very similar to ordinary tree training. We simply replace ordinary counts by weighted counts throughout the splitting calculations.

#example()[
Consider the following data:

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([x0], [x1], [y], [Weight],),
  table.hline(),
  [1.0], [2.1], [+], [0.5],
  [1.0], [1.1], [+], [0.125],
  [1.3], [1.0], [-], [0.125],
  [1.0], [1.0], [-], [0.125],
  [2.0], [1.0], [+], [0.125],
)
The weighted Gini impurity is

$ upright("WeightedGini") = 1 - \( 0.5 + 0.125 + 0.125 \)^2 - \( 0.125 + 0.125 \)^2 = 0.375 . $

] <exm->
=== The AdaBoost Algorithm
<the-adaboost-algorithm>
Suppose we have training data

$ \( x_1 \, y_1 \) \, dots.h \, \( x_n \, y_n \) \, quad y_i in { - 1 \, + 1 } . $

Initialize observation weights:

$ w_i^(\( 1 \)) = 1 / n . $

Then AdaBoost proceeds as follows.

+ For boosting round $m = 1 \, dots.h \, M$, fit a weak classifier $G_m$ using the current weights.

+ Compute the weighted classification error by the $m$-th classifier: $ "err"_m = upright("the total weights of misclassified observations") / upright("the total weights") = frac(sum_(upright("misclassified")) w_i^(\( m \)), sum_(upright("all")) w_i^(\( m \))) . $

+ Assign a weight to the weak classifier: \$\$
  \\alpha\_m
  =
  \\frac12
  \\log\\qty(\\frac{1-\\operatorname{err}\_m}{\\operatorname{err}\_m}).
  \$\$

+ Update observation weights and then normalize the weights so they sum to one: $ w_i^(\( m + 1 \)) arrow.l^(upright("normalize")) hat(w)_i^(\( m + 1 \)) arrow.l cases(delim: "{", w_i^(\( m \)) exp \( - alpha_m \) & upright("if observation ") i upright(" is correctly classified by the ") m upright("th weak learner,"), w_i^(\( m \)) exp \( alpha_m \) & upright("if observation ") i upright(" is misclassified by the ") m upright("th weak learner.")) $ that $ w_i^(\( m + 1 \)) = frac(hat(w)_i^(\( m + 1 \)), sum_j hat(w)_j^(\( m + 1 \))) . $ It is easy to see from the updating rule that AdaBoost puts more weight on observations that were misclassified.

+ Repeat the above process until the stop conditions are met.

The final model is then $ F_M \( x \) = sum_(m = 1)^M alpha_m G_m \( x \) \, $ and the final prediction is \$\$
\\hat G(x)
=
\\operatorname{sign}\\qty{F\_M(x)}.
\$\$

#block[
#callout(
body: 
[
In the classical AdaBoost derivation, the classifier weight is

\$\$
\\alpha\_m
=
\\frac12
\\log\\qty(\\frac{1-\\operatorname{err}\_m}{\\operatorname{err}\_m}).
\$\$

In practice, many implementations additionally introduce a learning rate $eta > 0$ and use

\$\$
\\alpha\_m
=
\\eta\\cdot
\\frac12
\\log\\qty(\\frac{1-\\operatorname{err}\_m}{\\operatorname{err}\_m}).
\$\$

Some textbooks instead write

\$\$
\\alpha\_m
=
\\eta\\cdot
\\log\\qty(\\frac{1-\\operatorname{err}\_m}{\\operatorname{err}\_m}),
\$\$

that is, without the factor $1 / 2$.

This does not fundamentally change the algorithm. The factor $1 / 2$ can simply be absorbed into the learning rate by replacing $eta$ with $eta \/ 2$. Therefore the two formulas differ only by a rescaling of the step size.

We mainly use the classical form with $1 / 2$ since it naturally appears in the standard derivation from exponential loss minimization and margin theory.

The learning rate controls how much each weak learner contributes to the final ensemble.

- A larger learning rate makes the model change more aggressively at each iteration.
- A smaller learning rate produces more gradual updates.

In practice, smaller learning rates are often combined with a larger number of estimators.

]
, 
title: 
[
Learning Rate and the $1 / 2$ Factor
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
$y F \( x \)$ is called the margin of the model $F$ on the observation $\( x \, y \)$. Since AdaBoost uses \$\\operatorname{sign}\\qty{F(x)}\$ as the final prediction rule, the margin can be interpreted as a confidence score for the prediction.

- If the margin is positive, the prediction is correct.
- If the margin is negative, the prediction is incorrect.
- A larger positive margin indicates a more confident prediction.
- A margin close to zero indicates uncertainty.

Notice that the observation weight updating formula can be rewritten as \$\$
w\_i^{(m+1)}
=
w\_i^{(m)}
\\exp\\qty(-\\alpha\_m y\_i G\_m(x\_i)),
\$\$ where $y_i G_m \( x_i \)$ is exactly the margin of the weak learner $G_m$ on observation $\( x_i \, y_i \)$.

Therefore, AdaBoost increases the weights of observations with small or negative margins and decreases the weights of observations with large positive margins. In this sense, AdaBoost can be viewed as an algorithm that attempts to improve the margin distribution by pushing margins toward larger positive values.

Margin theory is one of the central ideas in boosting and helps explain why boosting methods often continue to improve test performance even after the training error has already reached zero. We will discuss this topic in more detail later.

]
, 
title: 
[
Margin
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
The classifier weight is

$ alpha_m = eta dot.op log (frac(1 - "err"_m, "err"_m)) . $

- If $"err"_m$ is small, then the classifier is useful and $alpha_m$ is large.
- If $"err"_m$ is close to $0.5$, then the classifier is close to random guessing and $alpha_m$ is close to zero.
- If $"err"_m > 0.5$, then the classifier is worse than random guessing. In practice, this means the weak learner is not doing its job.

]
, 
title: 
[
Why the Learner Weight Makes Sense
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Why Does AdaBoost Work?
<why-does-adaboost-work>
One of the most surprising aspects of AdaBoost is that it often performs extremely well even when each individual learner is very weak.

A useful way to understand boosting is through the bias-variance tradeoff.

- Bagging and Random Forests mainly reduce variance by averaging many independent trees.
- Boosting mainly reduces bias by sequentially correcting the errors made by the current model.

At each boosting round, the new learner focuses more on the observations that are currently difficult to classify. As more learners are added, many simple decision rules combine into a much more flexible decision boundary. This sequential correction process allows AdaBoost to gradually improve the model while still using very simple base learners such as decision stumps.

In the early boosting rounds, the model often becomes substantially more accurate. However, if boosting continues too aggressively, variance may eventually increase and overfitting may occur. Several techniques are commonly used to control this effect, like shallow trees, smaller learning rates, subsampling and early stopping. Thus boosting can often achieve highly accurate models while still maintaining good generalization performance.

From a mathematical viewpoint, understanding #emph[why] AdaBoost works so well mathematically became one of the major research topics in statistical learning during the late 1990s and early 2000s. Many theoretical studies showed that AdaBoost is closely connected to several important topics, including additive modeling, exponential loss minimization and margin theory.

One particularly influential result showed that AdaBoost can be interpreted as a stagewise additive optimization procedure. Important theoretical works include #cite(<Freund1997>, form: "prose"), #cite(<Schapire1998>, form: "prose"), #cite(<Friedman2000>, form: "prose"), and #cite(<Breiman1999>, form: "prose"). These studies greatly influenced the later development of modern boosting methods such as Gradient Boosting and XGBoost.

== AdaBoost in Python
<adaboost-in-python>
The basic APIs are as usual. We use #NormalTok("AdaBoostClassifier"); from #NormalTok("sklearn.ensemble"); to implement AdaBoost. All the regular APIs are the same to other models.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" AdaBoostClassifier");],
[],
[#NormalTok("ada ");#OperatorTok("=");#NormalTok(" AdaBoostClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(max_depth");#OperatorTok("=");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("800");#NormalTok(",");],
[#NormalTok("    learning_rate");#OperatorTok("=");#FloatTok("0.1");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("ada.fit(X_train, y_train)");],));
]
#block[
#callout(
body: 
[
The original AdaBoost algorithm was designed for binary classification. Later extensions such as SAMME and SAMME.R generalized AdaBoost to multiclass classification problems. In #NormalTok("sklearn");, multiclass classification for #NormalTok("AdaBoostClassifier"); is implemented using the SAMME algorithm by default.

However, these variants are less important in modern statistical learning practice and will not be studied in detail in this course. One reason is that these extensions substantially increase the algorithmic complexity while introducing relatively limited new conceptual ideas beyond the original AdaBoost framework. In particular, SAMME.R relies heavily on predicted class probabilities, making the method more sensitive to the quality of probability estimation and numerical stability.

More importantly, many of the key ideas behind SAMME.R already overlap with the additive optimization viewpoint used in modern gradient boosting methods. As a result, modern frameworks such as Gradient Boosting and XGBoost provide a more general, flexible, and unified approach for both regression and classification problems.

Consequently, we will focus primarily on the original AdaBoost classifier as an accessible introduction to the core ideas of boosting before moving directly to Gradient Boosting. Reflecting a similar shift in modern machine learning practice, #NormalTok("sklearn"); has also deprecated SAMME.R in recent versions due to its reliance on probability estimation and its conceptual overlap with more general gradient boosting frameworks.

]
, 
title: 
[
SAMME and SAMME.R
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== The Margin Effect of AdaBoost
<the-margin-effect-of-adaboost>
AdaBoost is often explained as an algorithm that reduces training error. However, its behavior is more subtle than that.

For a binary classifier with labels $y_i in { - 1 \, + 1 }$, define the margin of observation $i$ as

$ "margin"_i = y_i F_M \( x_i \) . $

The sign of the margin determines whether the observation is classified correctly:

- if $"margin"_i > 0$, the observation is correctly classified;
- if $"margin"_i < 0$, the observation is misclassified.

The magnitude of the margin measures confidence. A large positive margin means the ensemble strongly supports the correct class.

=== Why Margins Matter
<why-margins-matter>
AdaBoost often continues to improve test performance even after the training error has reached zero. This can seem surprising. If the training error is already zero, what is left to improve?

The answer is margins.

After all training observations are classified correctly, AdaBoost may still increase the margins. Larger margins mean the classifier is more confident and more stable. This can improve generalization.

#block[
#callout(
body: 
[
Training error only asks whether the margin is positive.

The margin view also asks how positive it is.

]
, 
title: 
[
Margin view
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
This is one reason AdaBoost can work well in practice. It does not only try to classify points correctly. It also tends to push correctly classified points farther away from the decision boundary.

=== Margin study in Python
<margin-study-in-python>
The following example uses a manually crafted dataset. We track training error, test error, and margins as the number of boosting rounds increases.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("n ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3000");],
[#NormalTok("p ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");],
[#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(n, p))");],
[],
[#NormalTok("score ");#OperatorTok("=");#NormalTok(" (");],
[#NormalTok("    ");#FloatTok("1.2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("0");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#OperatorTok("-");#FloatTok("0.6");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("+");#NormalTok(" ");#FloatTok("1.0");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("0");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.4");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("-");#NormalTok(" ");#FloatTok("1.1");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("1");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.0");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.9");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("2");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.8");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("3");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#OperatorTok("-");#FloatTok("0.2");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.7");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ((X[:, ");#DecValTok("4");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (X[:, ");#DecValTok("5");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok("))");],
[#NormalTok("    ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.7");#NormalTok(" ");#OperatorTok("*");#NormalTok(" ((X[:, ");#DecValTok("6");#NormalTok("] ");#OperatorTok("<");#NormalTok(" ");#DecValTok("0");#NormalTok(") ");#OperatorTok("&");#NormalTok(" (X[:, ");#DecValTok("7");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.3");#NormalTok("))");],
[#NormalTok("    ");#OperatorTok("+");#NormalTok(" ");#FloatTok("0.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("8");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#FloatTok("0.1");#NormalTok(")");],
[#NormalTok("    ");#OperatorTok("-");#NormalTok(" ");#FloatTok("0.5");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (X[:, ");#DecValTok("9");#NormalTok("] ");#OperatorTok(">");#NormalTok(" ");#OperatorTok("-");#FloatTok("0.4");#NormalTok(")");],
[#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" (score ");#OperatorTok(">");#NormalTok(" np.quantile(score, ");#FloatTok("0.52");#NormalTok(")).astype(");#BuiltInTok("int");#NormalTok(") ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.5");#NormalTok(", stratify");#OperatorTok("=");#NormalTok("y, random_state");#OperatorTok("=");#DecValTok("1");],
[#NormalTok(")");],));
]
We first train the model.

#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" AdaBoostClassifier");],
[],
[#NormalTok("ada ");#OperatorTok("=");#NormalTok(" AdaBoostClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(max_depth");#OperatorTok("=");#DecValTok("2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("2000");#NormalTok(",");],
[#NormalTok("    learning_rate");#OperatorTok("=");#FloatTok("0.2");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("ada.fit(X_train, y_train)");],));
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.AdaBoostClassifier.html#:~:text=estimator,-object%2C%20default%3DNone")[estimator #text(fill: rgb("#000"))[estimator: object, default=None \
   \
  The base estimator from which the boosted ensemble is built. \
  Support for sample weighting is required, as well as proper \
  \`\`classes\_\`\` and \`\`n\_classes\_\`\` attributes. If \`\`None\`\`, then \
  the base estimator is :class:\`\~sklearn.tree.DecisionTreeClassifier\` \
  initialized with \`max\_depth=1\`. \
   \
  .. versionadded:: 1.2 \
  \`base\_estimator\` was renamed to \`estimator\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); DecisionTreeC...andom\_state=1)],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.AdaBoostClassifier.html#:~:text=n_estimators,-int%2C%20default%3D50")[n\_estimators #text(fill: rgb("#000"))[n\_estimators: int, default=50 \
   \
  The maximum number of estimators at which boosting is terminated. \
  In case of perfect fit, the learning procedure is stopped early. \
  Values must be in the range \`\[1, inf)\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 2000],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.AdaBoostClassifier.html#:~:text=learning_rate,-float%2C%20default%3D1.0")[learning\_rate #text(fill: rgb("#000"))[learning\_rate: float, default=1.0 \
   \
  Weight applied to each classifier at each boosting iteration. A higher \
  learning rate increases the contribution of each classifier. There is \
  a trade-off between the \`learning\_rate\` and \`n\_estimators\` parameters. \
  Values must be in the range \`(0.0, inf)\`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 0.2],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.AdaBoostClassifier.html#:~:text=random_state,-int%2C%20RandomState%20instance%20or%20None%2C%20default%3DNone")[random\_state #text(fill: rgb("#000"))[random\_state: int, RandomState instance or None, default=None \
   \
  Controls the random seed given at each \`estimator\` at each \
  boosting iteration. \
  Thus, it is only used when \`estimator\` exposes a \`random\_state\`. \
  Pass an int for reproducible output across multiple function calls. \
  See :term:\`Glossary \`.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 1],
)
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=criterion,-%7B%22gini%22%2C%20%22entropy%22%2C%20%22log_loss%22%7D%2C%20default%3D%22gini%22")[criterion #text(fill: rgb("#000"))[criterion: {\"gini\", \"entropy\", \"log\_loss\"}, default=\"gini\" \
   \
  The function to measure the quality of a split. Supported criteria are \
  \"gini\" for the Gini impurity and \"log\_loss\" and \"entropy\" both for the \
  Shannon information gain, see :ref:\`tree\_mathematical\_formulation\`.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'gini\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=splitter,-%7B%22best%22%2C%20%22random%22%7D%2C%20default%3D%22best%22")[splitter #text(fill: rgb("#000"))[splitter: {\"best\", \"random\"}, default=\"best\" \
   \
  The strategy used to choose the split at each node. Supported \
  strategies are \"best\" to choose the best split and \"random\" to choose \
  the best random split.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); \'best\'],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_depth,-int%2C%20default%3DNone")[max\_depth #text(fill: rgb("#000"))[max\_depth: int, default=None \
   \
  The maximum depth of the tree. If None, then nodes are expanded until \
  all leaves are pure or until all leaves contain less than \
  min\_samples\_split samples.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 2],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_samples_split,-int%20or%20float%2C%20default%3D2")[min\_samples\_split #text(fill: rgb("#000"))[min\_samples\_split: int or float, default=2 \
   \
  The minimum number of samples required to split an internal node: \
   \
  \- If int, then consider \`min\_samples\_split\` as the minimum number. \
  \- If float, then \`min\_samples\_split\` is a fraction and \
  \`ceil(min\_samples\_split \* n\_samples)\` are the minimum \
  number of samples for each split. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 2],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_samples_leaf,-int%20or%20float%2C%20default%3D1")[min\_samples\_leaf #text(fill: rgb("#000"))[min\_samples\_leaf: int or float, default=1 \
   \
  The minimum number of samples required to be at a leaf node. \
  A split point at any depth will only be considered if it leaves at \
  least \`\`min\_samples\_leaf\`\` training samples in each of the left and \
  right branches. This may have the effect of smoothing the model, \
  especially in regression. \
   \
  \- If int, then consider \`min\_samples\_leaf\` as the minimum number. \
  \- If float, then \`min\_samples\_leaf\` is a fraction and \
  \`ceil(min\_samples\_leaf \* n\_samples)\` are the minimum \
  number of samples for each node. \
   \
  .. versionchanged:: 0.18 \
  Added float values for fractions.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_weight_fraction_leaf,-float%2C%20default%3D0.0")[min\_weight\_fraction\_leaf #text(fill: rgb("#000"))[min\_weight\_fraction\_leaf: float, default=0.0 \
   \
  The minimum weighted fraction of the sum total of weights (of all \
  the input samples) required to be at a leaf node. Samples have \
  equal weight when sample\_weight is not provided.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_features,-int%2C%20float%20or%20%7B%22sqrt%22%2C%20%22log2%22%7D%2C%20default%3DNone")[max\_features #text(fill: rgb("#000"))[max\_features: int, float or {\"sqrt\", \"log2\"}, default=None \
   \
  The number of features to consider when looking for the best split: \
   \
  \- If int, then consider \`max\_features\` features at each split. \
  \- If float, then \`max\_features\` is a fraction and \
  \`max(1, int(max\_features \* n\_features\_in\_))\` features are considered at \
  each split. \
  \- If \"sqrt\", then \`max\_features=sqrt(n\_features)\`. \
  \- If \"log2\", then \`max\_features=log2(n\_features)\`. \
  \- If None, then \`max\_features=n\_features\`. \
   \
  .. note:: \
   \
  The search for a split does not stop until at least one \
  valid partition of the node samples is found, even if it requires to \
  effectively inspect more than \`\`max\_features\`\` features.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=random_state,-int%2C%20RandomState%20instance%20or%20None%2C%20default%3DNone")[random\_state #text(fill: rgb("#000"))[random\_state: int, RandomState instance or None, default=None \
   \
  Controls the randomness of the estimator. The features are always \
  randomly permuted at each split, even if \`\`splitter\`\` is set to \
  \`\`\"best\"\`\`. When \`\`max\_features \< n\_features\`\`, the algorithm will \
  select \`\`max\_features\`\` at random at each split before finding the best \
  split among them. But the best found split may vary across different \
  runs, even if \`\`max\_features=n\_features\`\`. That is the case, if the \
  improvement of the criterion is identical for several splits and one \
  split has to be selected at random. To obtain a deterministic behaviour \
  during fitting, \`\`random\_state\`\` has to be fixed to an integer. \
  See :term:\`Glossary \` for details.]]], table.cell(align: left, fill: rgb(0, 0, 0, 0%), stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: rgb(255, 94, 0)); 1],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=max_leaf_nodes,-int%2C%20default%3DNone")[max\_leaf\_nodes #text(fill: rgb("#000"))[max\_leaf\_nodes: int, default=None \
   \
  Grow a tree with \`\`max\_leaf\_nodes\`\` in best-first fashion. \
  Best nodes are defined as relative reduction in impurity. \
  If None then unlimited number of leaf nodes.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=min_impurity_decrease,-float%2C%20default%3D0.0")[min\_impurity\_decrease #text(fill: rgb("#000"))[min\_impurity\_decrease: float, default=0.0 \
   \
  A node will be split if this split induces a decrease of the impurity \
  greater than or equal to this value. \
   \
  The weighted impurity decrease equation is the following:: \
   \
  N\_t / N \* (impurity - N\_t\_R / N\_t \* right\_impurity \
  \- N\_t\_L / N\_t \* left\_impurity) \
   \
  where \`\`N\`\` is the total number of samples, \`\`N\_t\`\` is the number of \
  samples at the current node, \`\`N\_t\_L\`\` is the number of samples in the \
  left child, and \`\`N\_t\_R\`\` is the number of samples in the right child. \
   \
  \`\`N\`\`, \`\`N\_t\`\`, \`\`N\_t\_R\`\` and \`\`N\_t\_L\`\` all refer to the weighted sum, \
  if \`\`sample\_weight\`\` is passed. \
   \
  .. versionadded:: 0.19]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=class_weight,-dict%2C%20list%20of%20dict%20or%20%22balanced%22%2C%20default%3DNone")[class\_weight #text(fill: rgb("#000"))[class\_weight: dict, list of dict or \"balanced\", default=None \
   \
  Weights associated with classes in the form \`\`{class\_label: weight}\`\`. \
  If None, all classes are supposed to have weight one. For \
  multi-output problems, a list of dicts can be provided in the same \
  order as the columns of y. \
   \
  Note that for multioutput (including multilabel) weights should be \
  defined for each class of every column in its own dict. For example, \
  for four-class multilabel classification weights should be \
  \[{0: 1, 1: 1}, {0: 1, 1: 5}, {0: 1, 1: 1}, {0: 1, 1: 1}\] instead of \
  \[{1:1}, {2:5}, {3:1}, {4:1}\]. \
   \
  The \"balanced\" mode uses the values of y to automatically adjust \
  weights inversely proportional to class frequencies in the input data \
  as \`\`n\_samples / (n\_classes \* np.bincount(y))\`\` \
   \
  For multi-output, the weights of each column of y will be multiplied. \
   \
  Note that these weights will be multiplied with sample\_weight (passed \
  through the fit method) if sample\_weight is specified.]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=ccp_alpha,-non-negative%20float%2C%20default%3D0.0")[ccp\_alpha #text(fill: rgb("#000"))[ccp\_alpha: non-negative float, default=0.0 \
   \
  Complexity parameter used for Minimal Cost-Complexity Pruning. The \
  subtree with the largest cost complexity that is smaller than \
  \`\`ccp\_alpha\`\` will be chosen. By default, no pruning is performed. See \
  :ref:\`minimal\_cost\_complexity\_pruning\` for details. See \
  :ref:\`sphx\_glr\_auto\_examples\_tree\_plot\_cost\_complexity\_pruning.py\` \
  for an example of such pruning. \
   \
  .. versionadded:: 0.22]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); 0.0],
  table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #emph[]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); #link("https://scikit-learn.org/1.8/modules/generated/sklearn.tree.DecisionTreeClassifier.html#:~:text=monotonic_cst,-array-like%20of%20int%20of%20shape%20%28n_features%29%2C%20default%3DNone")[monotonic\_cst #text(fill: rgb("#000"))[monotonic\_cst: array-like of int of shape (n\_features), default=None \
   \
  Indicates the monotonicity constraint to enforce on each feature. \
  \- 1: monotonic increase \
  \- 0: no constraint \
  \- -1: monotonic decrease \
   \
  If monotonic\_cst is None, no constraints are applied. \
   \
  Monotonicity constraints are not supported for: \
  \- multiclass classifications (i.e. when \`n\_classes \> 2\`), \
  \- multioutput classifications (i.e. when \`n\_outputs\_ \> 1\`), \
  \- classifications trained on data with missing values. \
   \
  The constraints hold over the probability of the positive class. \
   \
  Read more in the :ref:\`User Guide \`. \
   \
  .. versionadded:: 1.4]]], table.cell(align: left, stroke: (paint: rgb(106, 105, 104, 23.2%), thickness: 2.25pt))[#set text(fill: black); None],
)
Then since the model contains the information of all trees, we could directly read them and use them about how the model works if we only use the first several trees. Here we use #NormalTok(".staged_predict()"); and #NormalTok(".staged_decision_function()"); methods.

- #NormalTok(".staged_predict()");: returns the predictions after each boosting round.
- #NormalTok(".staged_decision_function()");: returns the decision scores after each boosting round.

We would like to record all the training and test scores.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" accuracy_score");],
[],
[#NormalTok("train_acc ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("test_acc ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" pred_train, pred_test ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(");],
[#NormalTok("    ada.staged_predict(X_train), ada.staged_predict(X_test)");],
[#NormalTok("):");],
[#NormalTok("    train_acc.append(accuracy_score(y_train, pred_train))");],
[#NormalTok("    test_acc.append(accuracy_score(y_test, pred_test))");],));
]
In addition, the 10th-percentile margin is of our interesting, since we treat margin\<10% as no confidence.

#block[
#Skylighting(([#NormalTok("train_margin_10 ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("test_margin_10 ");#OperatorTok("=");#NormalTok(" []");],
[],
[#ControlFlowTok("for");#NormalTok(" score_train, score_test ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(");],
[#NormalTok("    ada.staged_decision_function(X_train),");],
[#NormalTok("    ada.staged_decision_function(X_test),");],
[#NormalTok("):");],
[#NormalTok("    train_margins ");#OperatorTok("=");#NormalTok(" y_train ");#OperatorTok("*");#NormalTok(" score_train");],
[#NormalTok("    test_margins ");#OperatorTok("=");#NormalTok(" y_test ");#OperatorTok("*");#NormalTok(" score_test");],
[],
[#NormalTok("    train_margin_10.append(np.quantile(train_margins, ");#FloatTok("0.1");#NormalTok("))");],
[#NormalTok("    test_margin_10.append(np.quantile(test_margins, ");#FloatTok("0.1");#NormalTok("))");],));
]
We also need to test when the training score becomes #NormalTok("1.0");, and when the test score is the highest. Then we have the interesting output.

#block[
#Skylighting(([#NormalTok("first_full_train ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("next");#NormalTok("((i ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#ControlFlowTok("for");#NormalTok(" i, s ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("enumerate");#NormalTok("(train_acc) ");#ControlFlowTok("if");#NormalTok(" s ");#OperatorTok("==");#NormalTok(" ");#FloatTok("1.0");#NormalTok("), ");#VariableTok("None");#NormalTok(")");],
[#NormalTok("best_test_round ");#OperatorTok("=");#NormalTok(" np.argmax(test_acc) ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"First round with training accuracy 1:\"");#NormalTok(", first_full_train)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Test accuracy at that round:\"");#NormalTok(", test_acc[first_full_train ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best test accuracy:\"");#NormalTok(", np.");#BuiltInTok("max");#NormalTok("(test_acc))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best test round:\"");#NormalTok(", best_test_round)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Final training accuracy:\"");#NormalTok(", train_acc[");#OperatorTok("-");#DecValTok("1");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Final test accuracy:\"");#NormalTok(", test_acc[");#OperatorTok("-");#DecValTok("1");#NormalTok("])");],));
#block[
#Skylighting(([#NormalTok("First round with training accuracy 1: 426");],
[#NormalTok("Test accuracy at that round: 0.9746666666666667");],
[#NormalTok("Best test accuracy: 0.9806666666666667");],
[#NormalTok("Best test round: 1121");],
[#NormalTok("Final training accuracy: 1.0");],
[#NormalTok("Final test accuracy: 0.98");],));
]
]
We could plot the curves. From the plot, we can see that after the training score becomes 1.0, the model is still improving and the test score reaches the highest long after.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[],
[#NormalTok("plt.plot(train_acc, label");#OperatorTok("=");#StringTok("\"training accuracy\"");#NormalTok(")");],
[#NormalTok("plt.plot(test_acc, label");#OperatorTok("=");#StringTok("\"testing accuracy\"");#NormalTok(")");],
[],
[#NormalTok("plt.axvline(");],
[#NormalTok("    first_full_train,");],
[#NormalTok("    color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(",");],
[#NormalTok("    linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(",");],
[#NormalTok("    label");#OperatorTok("=");#StringTok("\"training accuracy first reaches 1\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("plt.axvline(best_test_round, color");#OperatorTok("=");#StringTok("\"gray\"");#NormalTok(", linestyle");#OperatorTok("=");#StringTok("\":\"");#NormalTok(", label");#OperatorTok("=");#StringTok("\"best testing accuracy\"");#NormalTok(")");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"boosting round\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"accuracy\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Accuracy Curves\"");#NormalTok(")");],
[#NormalTok("plt.legend()");#OperatorTok(";");],));
#box(image("contents\\2/boost_files/figure-typst/cell-10-output-1.svg"))

We may also plot the 10th-percentile margin curve. The 10th-percentile margin represents the lower tail of the margin distribution, that is, the examples on which the classifier is least confident.

From the plot, we can see that even after the training accuracy reaches 1.0, the margins may still continue to change. This shows that #NormalTok("AdaBoost"); is not merely optimizing training accuracy; it continues to adjust the additive model in order to improve the margin distribution and increase confidence.

- If the lower-percentile margin continues to increase while test performance remains stable or improves, this suggests that the model is still improving its confidence on difficult cases and is not yet clearly overfitting.
- If the lower-percentile margin decreases together with decreasing validation or test performance, this suggests that the model may be becoming less reliable on difficult cases and may be starting to overfit.

#Skylighting(([#NormalTok("plt.plot(train_margin_10, label");#OperatorTok("=");#StringTok("\"training 10th percentile margin\"");#NormalTok(")");],
[#NormalTok("plt.plot(test_margin_10, label");#OperatorTok("=");#StringTok("\"testing 10th percentile margin\"");#NormalTok(")");],
[],
[#NormalTok("plt.axvline(");],
[#NormalTok("    first_full_train,");],
[#NormalTok("    color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(",");],
[#NormalTok("    linestyle");#OperatorTok("=");#StringTok("\"--\"");#NormalTok(",");],
[#NormalTok("    label");#OperatorTok("=");#StringTok("\"training accuracy first reaches 1\"");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("plt.axhline(");#DecValTok("0");#NormalTok(", color");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(", linewidth");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("plt.xlabel(");#StringTok("\"boosting round\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"margin\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"10th Percentile Margin\"");#NormalTok(")");],
[#NormalTok("plt.legend()");#OperatorTok(";");],));
#box(image("contents\\2/boost_files/figure-typst/cell-11-output-1.svg"))

== Tuning AdaBoost Hyperparameters
<tuning-adaboost-hyperparameters>
The most important AdaBoost hyperparameters are:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Parameter], [Role],),
  table.hline(),
  [#NormalTok("n_estimators");], [Number of weak learners.],
  [#NormalTok("learning_rate");], [Shrinks the contribution of each learner.],
  [#NormalTok("estimator__max_depth");], [Complexity of the base tree.],
  [#NormalTok("estimator__min_samples_leaf");], [Smoothness of each base tree.],
)
The two most important parameters are #NormalTok("n_estimators"); and #NormalTok("learning_rate");.

=== Learning Rate and Number of Trees
<learning-rate-and-number-of-trees>
There is a strong tradeoff:

- smaller #NormalTok("learning_rate"); usually needs larger #NormalTok("n_estimators");\;
- larger #NormalTok("learning_rate"); learns faster but can overfit or become unstable;
- smaller #NormalTok("learning_rate"); often gives smoother and more stable models.

=== Base Tree Depth
<base-tree-depth>
Decision stumps use #NormalTok("max_depth=1");. They are common because AdaBoost was originally designed around weak learners. Using deeper trees allows each boosting round to model interactions. In most cases, AdaBoost use depths from 1 to 3. Deeper trees are stronger learners, but they also increase the risk of overfitting.

=== Grid Search for AdaBoost
<grid-search-for-adaboost>
The following code tunes AdaBoost by grid search cross-validation.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" AdaBoostClassifier");],
[],
[#NormalTok("ada ");#OperatorTok("=");#NormalTok(" AdaBoostClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("0");#NormalTok("),");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"n_estimators\"");#NormalTok(": [");#DecValTok("100");#NormalTok(", ");#DecValTok("300");#NormalTok(", ");#DecValTok("600");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.1");#NormalTok(", ");#FloatTok("0.5");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"estimator__max_depth\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"estimator__min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(ada, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", scoring");#OperatorTok("=");#StringTok("\"accuracy\"");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[#NormalTok("grid.best_params_");],));
]
Tuning should be done using validation data or cross-validation. The test set should be saved for the final evaluation.

#block[
#callout(
body: 
[
AdaBoost can be sensitive to mislabeled observations and outliers.

Because it repeatedly increases the weights of difficult observations, noisy points may receive too much attention.

]
, 
title: 
[
Noisy data
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
=== Example: #NormalTok("AdaBoost"); on a Nonlinear Classification Problem
<example-adaboost-on-a-nonlinear-classification-problem>
We first use a synthetic nonlinear classification problem. This example shows that many weak learners can create a flexible decision boundary.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" make_moons");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("X, y ");#OperatorTok("=");#NormalTok(" make_moons(n_samples");#OperatorTok("=");#DecValTok("1500");#NormalTok(", noise");#OperatorTok("=");#FloatTok("0.25");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X, y, test_size");#OperatorTok("=");#FloatTok("0.3");#NormalTok(", stratify");#OperatorTok("=");#NormalTok("y, random_state");#OperatorTok("=");#DecValTok("1");],
[#NormalTok(")");],));
]
Fit a baseline stump and an AdaBoost model.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.tree ");#ImportTok("import");#NormalTok(" DecisionTreeClassifier");],
[#ImportTok("from");#NormalTok(" sklearn.ensemble ");#ImportTok("import");#NormalTok(" AdaBoostClassifier");],
[],
[#NormalTok("stump ");#OperatorTok("=");#NormalTok(" DecisionTreeClassifier(max_depth");#OperatorTok("=");#DecValTok("1");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("ada ");#OperatorTok("=");#NormalTok(" AdaBoostClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(max_depth");#OperatorTok("=");#DecValTok("1");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("300");#NormalTok(",");],
[#NormalTok("    learning_rate");#OperatorTok("=");#FloatTok("0.05");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("stump.fit(X_train, y_train)");],
[#NormalTok("ada.fit(X_train, y_train)");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Stump accuracy:\"");#NormalTok(", stump.score(X_test, y_test))");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"AdaBoost accuracy:\"");#NormalTok(", ada.score(X_test, y_test))");],));
#block[
#Skylighting(([#NormalTok("Stump accuracy: 0.8488888888888889");],
[#NormalTok("AdaBoost accuracy: 0.9222222222222223");],));
]
]
Now tune the AdaBoost model.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" sklearn.metrics ");#ImportTok("import");#NormalTok(" accuracy_score");],
[],
[#NormalTok("ada_base ");#OperatorTok("=");#NormalTok(" AdaBoostClassifier(");],
[#NormalTok("    estimator");#OperatorTok("=");#NormalTok("DecisionTreeClassifier(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok("), random_state");#OperatorTok("=");#DecValTok("1");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"n_estimators\"");#NormalTok(": [");#DecValTok("100");#NormalTok(", ");#DecValTok("300");#NormalTok(", ");#DecValTok("600");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.03");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.1");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"estimator__max_depth\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"estimator__min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    ada_base, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", scoring");#OperatorTok("=");#StringTok("\"accuracy\"");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");],
[#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],
[#NormalTok("best_ada ");#OperatorTok("=");#NormalTok(" grid.best_estimator_");],
[],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best parameters:\"");#NormalTok(", grid.best_params_)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Best CV accuracy:\"");#NormalTok(", grid.best_score_)");],
[#BuiltInTok("print");#NormalTok("(");#StringTok("\"Test accuracy:\"");#NormalTok(", best_ada.score(X_test, y_test))");],));
#block[
#Skylighting(([#NormalTok("Best parameters: {'estimator__max_depth': 2, 'estimator__min_samples_leaf': 5, 'learning_rate': 0.1, 'n_estimators': 600}");],
[#NormalTok("Best CV accuracy: 0.9466666666666667");],
[#NormalTok("Test accuracy: 0.94");],));
]
]
== XGBoost and Gradient Boosting
<xgboost-and-gradient-boosting>
The core idea of boosting is to sequentially train models in order to correct the errors made by earlier models. A natural idea is therefore:

+ fit a model
+ compute the residuals
+ fit a new model to the residuals
+ repeat

We mainly consider regression problems at the current stage.

=== Additive model
<additive-model>
The above idea leads directly to #strong[Gradient Boosting]. When the models used are trees, the model is also called Gradient Boosted Decision Trees (GBDT).

Gradient Boosting builds an additive model of the form

$ F_M \( x \) = sum_(m = 1)^M beta_m h_m \( x \) $

where

- $h_m \( x \)$ is usually a small regression tree
- $beta_m$ is a coefficient
- the model is built sequentially

Unlike bagging, where trees are trained independently, boosting trains each new tree based on the current errors of the model.

=== Functional gradient viewpoint
<functional-gradient-viewpoint>
In ordinary optimization problems, we optimize finitely many parameters. For example, in linear regression we optimize the coefficient vector

$ beta = \( beta_1 \, dots.h \, beta_p \) . $

Gradient Boosting takes a different viewpoint. Instead of directly optimizing finitely many parameters, it attempts to optimize the prediction function itself.

The model is built additively:

$ F_(m + 1) \( x \) = F_m \( x \) + f_m \( x \) \, $

where each new function $f_m \( x \)$ is usually a small regression tree.

Thus each boosting step adds a new basis function to the model. Since the space of possible functions is extremely large, Gradient Boosting is often interpreted as a form of gradient descent in function space, also called functional gradient descent.

Conceptually:

- ordinary gradient descent updates parameters
- Gradient Boosting updates functions

=== Regression tree fitting
<regression-tree-fitting>
In order to find the best model $F \( x \)$, we would like to minimize the empirical loss function

$ L \( F \) = sum_(i = 1)^n l \( y_i \, F \( x_i \) \) \, $

where ${ \( x_i \, y_i \) }$ is the training dataset. One of the most common choices for the loss function is the squared-error loss $ L \( F \) = sum_(i = 1)^n \( y_i - F \( x_i \) \)^2 . $

Assume the current model is $F_m \( x \)$. After adding a new tree $f_m \( x \)$, the next model becomes

$ F_(m + 1) \( x \) = F_m \( x \) + f_m \( x \) . $

The new tree $f_m \( x \)$ is chosen to reduce the loss function as much as possible.

Now consider the first-order Taylor expansion of the loss function:

$ l \( y_i \, F_m \( x_i \) + f_m \( x_i \) \) approx l \( y_i \, F_m \( x_i \) \) + g_i f_m \( x_i \) \, $

where

$ g_i = frac(partial l \( y_i \, F_m \( x_i \) \), partial F_m \( x_i \))\|_(F = F_m) . $

This gives a linear approximation of the loss function in terms of the update $f_m \( x_i \)$.

Since the first-order Taylor approximation is linear, the negative gradient gives the direction of steepest descent. Therefore we define the pseudo-residual

$ r_i = - g_i = - frac(partial l \( y_i \, F \( x_i \) \), partial F \( x_i \))\|_(F = F_m) . $

The pseudo-residual plays the role of the error signal that the next tree should fit.

Assume that the new tree splits the dataset into regions $R_1 \, dots.h \, R_s$, and for each region $R_j$ a value $s_j$ is assigned. We would like the tree to approximate the pseudo-residuals $r_i$. Therefore we choose the tree to minimize

$ sum_(j = 1)^s sum_(x_i in R_j) \( r_i - s_j \)^2 . $

For a fixed region $R_j$, the optimal value of $s_j$ is the mean of the observations inside that region:

$ s_j = frac(1, \| R_j \|) sum_(x_i in R_j) r_i . $

Therefore, the new tree $f_m \( x \)$ is simply a regression tree (trained using RSS) with target values $r_i$.

#block[
#callout(
body: 
[
$r_i$ is called a #emph[pseudo-residual] because it is technically a negative gradient rather than an ordinary residual. However, it plays the role of the residual in Gradient Boosting.

For squared-error loss

$ l \( y \, F \( x \) \) = \( y - F \( x \) \)^2 \, $

we have

$ r_i = 2 \( y_i - F_m \( x_i \) \) \, $

which is proportional to the ordinary residual.

Therefore, under $L^2$ loss, Gradient Boosting can literally be interpreted as fitting residuals.

]
, 
title: 
[
Pseudo-residual
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== XGBoost: Initial idea
<xgboost-initial-idea>
XGBoost stands for #strong[Extreme Gradient Boosting]. Its mathematical foundation can be viewed as a modified and improved version of GBDT.

XGBoost became one of the most successful shallow machine learning models in modern practice. In addition to its mathematical improvements, it also introduced many engineering innovations that significantly improved efficiency and scalability. After the success of XGBoost, several related models such as LightGBM and CatBoost were also developed and became widely used.

We mainly focus on the mathematical ideas behind XGBoost. The motivation is very similar to GBDT. We consider the additive model

$ F_(m + 1) \( x \) = F_m \( x \) + f_m \( x \) \, $

and would like to minimize the empirical loss

$ L \( F \) = sum_(i = 1)^n l \( y_i \, F \( x_i \) \) . $

Assume the current model is $F_m \( x \)$. After adding a new tree $f_m \( x \)$, we obtain

$ F_(m + 1) \( x \) = F_m \( x \) + f_m \( x \) . $

Instead of using only first-order information as in GBDT, XGBoost uses a local second-order Taylor approximation of the loss function at each boosting iteration:

$ l \( y_i \, F_m \( x_i \) + f_m \( x_i \) \) approx l \( y_i \, F_m \( x_i \) \) + g_i f_m \( x_i \) + 1 / 2 h_i f_m \( x_i \)^2 \, $

where

$ g_i = frac(partial l \( y_i \, F \( x_i \) \), partial F \( x_i \))\|_(F = F_m) \, $

and

$ h_i = frac(partial^2 l \( y_i \, F \( x_i \) \), partial F \( x_i \)^2)\|_(F = F_m) . $

Here

- $g_i$ measures the gradient
- $h_i$ measures the curvature of the loss function

Thus, XGBoost uses both gradient and curvature information.

=== Intuition of the quadratic approximation
<intuition-of-the-quadratic-approximation>
The first-order Taylor expansion used in GBDT gives only a linear approximation of the loss function. In contrast, the second-order Taylor expansion gives a quadratic approximation:

$ g_i f + 1 / 2 h_i f^2 . $

As a function of $f$, its derivative is

$ g_i + h_i f . $

Setting this equal to zero gives the critical point

$ f = - g_i / h_i . $

This can be viewed as the approximately optimal update suggested by the local quadratic approximation of the loss function.

=== Tree structure in XGBoost
<tree-structure-in-xgboost>
Assume that the new tree splits the dataset into regions

$ R_1 \, dots.h \, R_s \, $

and assigns a prediction value $s_j$ to region $R_j$. Then for every observation inside region $R_j$, we have

$ f_m \( x_i \) = s_j . $

Substituting this into the quadratic approximation gives the approximate objective

$ sum_(j = 1)^s sum_(x_i in R_j) (g_i s_j + 1 / 2 h_i s_j^2) . $

For a fixed tree structure, we minimize this expression with respect to $s_j$.

Differentiating with respect to $s_j$ gives

$ sum_(x_i in R_j) \( g_i + h_i s_j \) = 0 . $

Therefore,

$ s_j = - frac(sum_(x_i in R_j) g_i, sum_(x_i in R_j) h_i) . $

If we define

$ G_j = sum_(x_i in R_j) g_i \, quad H_j = sum_(x_i in R_j) h_i \, $

then the optimal leaf value becomes

$ s_j = - G_j / H_j . $

#block[
#callout(
body: 
[
This tree is NOT an ordinary CART regression tree trained with RSS.

- In GBDT, we explicitly train a CART regression tree to fit the pseudo-residuals.
- In XGBoost, the leaf values are derived directly from the quadratic approximation of the objective function itself.

Therefore, although XGBoost trees may look structurally similar to CART trees, mathematically they are solving a different optimization problem.

]
, 
title: 
[
Important difference from ordinary CART
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
=== Regularization
<regularization-1>
So far we derived the basic XGBoost objective using the second-order Taylor approximation.

However, minimizing only the training loss may produce overly complex trees and lead to overfitting. Therefore XGBoost introduces an explicit regularization term to control tree complexity.

Suppose the new tree $f_m \( x \)$ has

- $T$ leaves
- leaf values $s_1 \, dots.h \, s_T$

XGBoost defines the regularization term

$ Omega \( f_m \) = gamma T + 1 / 2 lambda sum_(j = 1)^T s_j^2 . $

Therefore the objective becomes

$ L \( F_m + f_m \) + Omega \( f_m \) . $

Here

- $gamma T$ penalizes the number of leaves
- $1 / 2 lambda sum s_j^2$ penalizes large leaf values

Using the second-order Taylor approximation and grouping terms by regions gives

$ sum_(j = 1)^T [G_j s_j + 1 / 2 \( H_j + lambda \) s_j^2] + gamma T . $

For a fixed tree structure, we minimize the objective with respect to $s_j$. Differentiating gives

$ G_j + \( H_j + lambda \) s_j = 0 . $

Therefore the optimal leaf value becomes

$ s_j = - frac(G_j, H_j + lambda) . $

Compared with the non-regularized version

$ s_j = - G_j / H_j \, $

the regularization term enlarges the denominator and shrinks the leaf predictions toward zero. This effect is similar to ridge regularization in linear regression.

Substituting the optimal leaf values back into the objective gives

$ - 1 / 2 sum_(j = 1)^T frac(G_j^2, H_j + lambda) + gamma T . $

This quantity is used by XGBoost to evaluate the quality of candidate tree splits.

Therefore, unlike ordinary CART trees which use RSS or Gini impurity, XGBoost derives its splitting criterion directly from the regularized optimization objective.

=== Learning rate
<learning-rate>
In practice, although XGBoost computes the best update tree $f_m$, it usually does not add the full tree update directly to the model. Instead, the update is scaled by a learning rate (also called the shrinkage parameter):

$ F_(m + 1) \( x \) = F_m \( x \) + eta f_m \( x \) \, $

where

$ 0 < eta lt.eq 1 . $

Thus every new tree contributes only partially to the final model.

Equivalently, after computing the optimal leaf value

$ s_j = - frac(G_j, H_j + lambda) \, $

XGBoost actually uses the scaled leaf prediction

$ eta s_j . $

Therefore shrinkage reduces the influence of each individual tree.

The parameter $eta$ is called the #strong[learning rate] or shrinkage parameter.

#block[
#callout(
body: 
[
The mathematical foundation of XGBoost is built on three main ideas:

- second-order Taylor approximation of the loss function
- explicit regularization on tree complexity
- shrinkage through the learning rate

In addition to these mathematical ideas, XGBoost also introduced many important engineering optimizations such as:

- parallel tree construction
- efficient handling of sparse data
- cache-aware memory access
- approximate split finding algorithms

These engineering improvements are one of the main reasons why XGBoost became highly successful in practical machine learning applications.

]
, 
title: 
[
XGBoost in practice
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== GBDT and XGBoost for classification
<gbdt-and-xgboost-for-classification>
Both GBDT and XGBoost can naturally be extended from regression to classification problems. The overall framework remains the same:

- additive tree model
- boosting optimization
- sequentially adding trees
- minimizing a loss function

The main difference is the choice of the loss function.

For binary classification, boosting methods commonly use logistic loss

$ l \( y \, p \) = - [y log p + \( 1 - y \) log \( 1 - p \)] . $

The model output $F \( x \)$ is converted into probabilities using the logistic function $ p \( x \) = frac(1, 1 + e^(- F \( x \))) . $ For multiclass classification, softmax-based loss functions are commonly used.

The difference between GBDT and XGBoost remains the same as in regression:

- GBDT uses first-order gradients (pseudo-residuals)
- XGBoost uses second-order Taylor approximation together with regularization

Thus both methods provide a unified framework for regression and classification problems.

#block[
#callout(
body: 
[
AdaBoost can be interpreted as a special case of Gradient Boosting using the exponential loss function

$ l \( y \, F \( x \) \) = e^(- y F \( x \)) \, $

where

$ y in { - 1 \, 1 } . $

The empirical loss becomes

$ L \( F \) = sum_(i = 1)^n e^(- y_i F \( x_i \)) . $

This loss heavily penalizes observations with negative margins

$ y_i F \( x_i \) . $

In particular:

- correctly classified points with large positive margins receive very small loss
- misclassified points receive exponentially large loss

Therefore minimizing exponential loss naturally increases the weights of difficult observations, which explains the adaptive reweighting behavior of AdaBoost.

Taking derivative gives

$ frac(partial l \( y_i \, F \( x_i \) \), partial F \( x_i \)) = - y_i e^(- y_i F \( x_i \)) . $

Thus the pseudo-residual becomes

$ r_i = y_i e^(- y_i F \( x_i \)) . $

Observations with small or negative margins receive much larger pseudo-residuals and therefore larger influence in the next boosting step.

From this viewpoint, AdaBoost can be interpreted as functional gradient descent under exponential loss.

Gradient Boosting generalizes this idea by allowing arbitrary differentiable loss functions rather than only exponential loss.

]
, 
title: 
[
AdaBoost as Gradient Boosting with exponential loss
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== XGBoost in Python
<xgboost-in-python>
XGBoost is implemented using the library #NormalTok("XGBoost");. You may go to the #link("https://xgboost.ai/")[offical website] for more information. We will cover the basic usage in this lecture.

A typical XGBoost regression model looks like this.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" xgboost ");#ImportTok("import");#NormalTok(" XGBRegressor");],
[],
[#NormalTok("xgb ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    objective");#OperatorTok("=");#StringTok("\"reg:squarederror\"");#NormalTok(",");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("500");#NormalTok(",");],
[#NormalTok("    learning_rate");#OperatorTok("=");#FloatTok("0.05");#NormalTok(",");],
[#NormalTok("    max_depth");#OperatorTok("=");#DecValTok("3");#NormalTok(",");],
[#NormalTok("    subsample");#OperatorTok("=");#FloatTok("0.8");#NormalTok(",");],
[#NormalTok("    colsample_bytree");#OperatorTok("=");#FloatTok("0.8");#NormalTok(",");],
[#NormalTok("    reg_lambda");#OperatorTok("=");#FloatTok("1.0");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("xgb.fit(X_train, y_train)");],));
]
The #NormalTok("objective=\"reg:squarederror\""); is to indicate the loss function. The default is #NormalTok("\"reg:squarederror\""); that is regression with squared loss. More loss function can be found in the #link("https://xgboost.readthedocs.io/en/stable/parameter.html#learning-task-parameters")[documnet].

The most important hyperparameters are:

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Parameter], [Meaning],),
  table.hline(),
  [#NormalTok("n_estimators");], [Number of boosting rounds.],
  [#NormalTok("learning_rate");], [Learning rate.],
  [#NormalTok("max_depth");], [Depth of each tree.],
  [#NormalTok("subsample");], [Fraction of observations used for each tree.],
  [#NormalTok("colsample_bytree");], [Fraction of predictors used for each tree.],
  [#NormalTok("reg_lambda");], [L2 regularization on leaf weights.],
  [#NormalTok("reg_alpha");], [L1 regularization on leaf weights.],
)
Most of them are straightforward. I only discuss these since they are not from the theory.

#block[
#callout(
body: 
[
#NormalTok("subsample"); controls the fraction of training observations randomly sampled for each boosting round. For example #NormalTok("subsample=0.8"); means that each new tree is trained using only 80% of the observations.

This introduces additional randomness into boosting, similar to bagging in Random Forests. Smaller values of #NormalTok("subsample"); and reduce variance and improve generalization. However, if the value is too small, the model may underfit.

]
, 
title: 
[
#NormalTok("subsample");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#NormalTok("colsample_bytree"); controls the fraction of predictors randomly sampled for each tree. For example #NormalTok("colsample_bytree=0.7"); means that each tree only considers 70% of the predictors.

This idea is similar to feature subsampling in Random Forests. It reduces correlation between trees and can improve robustness and generalization performance.

]
, 
title: 
[
#NormalTok("colsample_bytree");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#NormalTok("reg_alpha"); is the L1 regularization parameter on leaf weights. Previously we introduced the L2 regularization term $1 / 2 lambda sum s_j^2$, which corresponds to ridge-style regularization.

XGBoost can also include an L1 penalty \$\$
\\alpha\\sum\\abs{s\_j},
\$\$ which is controlled by #NormalTok("reg_alpha");. L1 regularization tends to shrink some leaf values exactly to zero, producing sparser models and sometimes improving interpretability and robustness. This corresponds to lasso-style regularization.

We don't introduce L1 regularization in the first place because it might make the math formula too complicated.

]
, 
title: 
[
#NormalTok("reg_alpha");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Example grid:

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[#ImportTok("from");#NormalTok(" xgboost ");#ImportTok("import");#NormalTok(" XGBRegressor");],
[],
[#NormalTok("xgb ");#OperatorTok("=");#NormalTok(" XGBRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"n_estimators\"");#NormalTok(": [");#DecValTok("200");#NormalTok(", ");#DecValTok("500");#NormalTok(", ");#DecValTok("800");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.03");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.1");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": [");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": [");#FloatTok("0.7");#NormalTok(", ");#FloatTok("0.9");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": [");#FloatTok("0.7");#NormalTok(", ");#FloatTok("0.9");#NormalTok(", ");#FloatTok("1.0");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": [");#FloatTok("1.0");#NormalTok(", ");#FloatTok("5.0");#NormalTok(", ");#FloatTok("10.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid ");#OperatorTok("=");#NormalTok(" GridSearchCV(xgb, param_grid");#OperatorTok("=");#NormalTok("param_grid, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("grid.fit(X_train, y_train)");],));
]
#block[
#callout(
body: 
[
Although for boosting parallel computing is in the nature as in bagging, #NormalTok("XGBoost"); successfully support it and offers #NormalTok("n_jobs"); to accelerate. The API is similar, so we could use #NormalTok("n_jobs=-1"); to indicate using all CPU cores.

Similar to bagging, for a nested struture like #NormalTok("GridSearchCV"); with #NormalTok("XGBoost");, we only apply #NormalTok("n_jobs"); to one of them. In general, if it is a small dataset, we let #NormalTok("GridSearchCV"); use multiple cores. If it is a large dataset, we let #NormalTok("XGBoost"); use multiple cores.

]
, 
title: 
[
#NormalTok("n_jobs");
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Tuning XGBoost
<tuning-xgboost>
If there are enough computing resources, to tune #NormalTok("XGBoost"); is no different from other models. However since the model becomes more complicated, it usually takes longer to go through the whole grid search. In this case, usually we make some modifications to the workflow.

=== #NormalTok("RandomSearchCV");
<randomsearchcv>
We already show the code of #NormalTok("RandomSearchCV"); before. Here we give more explanations.

#NormalTok("RandomSearchCV"); is to search random combinations of hyperparameters. Therefore it is used to do a rough search in a very large parameter space. Other than the #NormalTok("param_grid"); like #NormalTok("GridSearchCV");, #NormalTok("RandomSearchCV"); needs #NormalTok("n_iter"); to indicate how many combinations one wants to test.

Since now we can search in a very large space, usually we make a really large space, by directly choosing hyperparameters based on distributions. We use distributions from the library #NormalTok("scipy.stats");. Here we give an examples.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" randint, uniform");],
[],
[#NormalTok("param_distributions ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"n_estimators\"");#NormalTok(": randint(");#DecValTok("100");#NormalTok(", ");#DecValTok("1000");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": randint(");#DecValTok("2");#NormalTok(", ");#DecValTok("8");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": uniform(");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.19");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": uniform(");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.4");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": uniform(");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.4");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok("),");],
[#NormalTok("}");],
[],
[#NormalTok("random_search ");#OperatorTok("=");#NormalTok(" RandomizedSearchCV(");],
[#NormalTok("    xgb, param_distributions");#OperatorTok("=");#NormalTok("param_distributions, n_iter");#OperatorTok("=");#DecValTok("30");#NormalTok(", cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("0");],
[#NormalTok(")");],));
]
=== Workflow
<workflow>
A practical tuning workflow is often a two-stage process.

First, run #NormalTok("RandomizedSearchCV"); over a relatively large parameter space. This gives a rough idea of promising regions in the hyperparameter space.

Then, based on the best combination found by random search, choose a smaller and more refined grid around those values and run #NormalTok("GridSearchCV");.

If the refined grid is still too slow, we can tune parameters in smaller batches. A common strategy is:

+ tune model complexity parameters first, such as #NormalTok("max_depth");
+ tune learning rate
+ tune sampling parameters, such as #NormalTok("subsample"); and #NormalTok("colsample_bytree");
+ tune regularization parameters, such as #NormalTok("reg_lambda"); and #NormalTok("reg_alpha");

This workflow is not guaranteed to find the global best combination, but it is usually much more practical than running one huge exhaustive grid search.

=== Early Stopping
<early-stopping>
Boosting may eventually overfit if too many trees are added. Early stopping helps prevent this by monitoring validation performance during training.

In principle, #NormalTok("n_estimators"); can be tuned together with other hyperparameters using grid search or similar methods. In practice, however, it is often determined separately through early stopping.

Conceptually, the procedure is simple:

+ Split the training data into a training part and a validation part.
+ Fit trees sequentially.
+ Monitor the validation error after each boosting round.
+ Stop when the validation performance no longer improves.

In XGBoost, this is commonly implemented using an evaluation set together with #NormalTok("early_stopping_rounds");. For example, #NormalTok("early_stopping_rounds=20"); means that training stops if the validation score does not improve for 20 consecutive boosting rounds.

#block[
#Skylighting(([#NormalTok("xgb ");#OperatorTok("=");#NormalTok(" XGBRegressor(early_stopping_rounds");#OperatorTok("=");#DecValTok("20");#NormalTok(")");],
[#NormalTok("xgb.fit(X_train, y_train, eval_set");#OperatorTok("=");#NormalTok("[(X_val, y_val)])");],));
]
Exact early-stopping syntax can differ across XGBoost versions, so it is useful to check the installed version when writing production code. The current stynax comes from #link("https://xgboost.readthedocs.io/en/release_3.2.0/python/sklearn_estimator.html#early-stopping")[XGBoost 3.2.0].

#block[
#callout(
body: 
[
In modern machine learning practice, workflows often use tools such as #NormalTok("Optuna"); and various #NormalTok("AutoML"); frameworks for hyperparameter optimization.

Unlike #NormalTok("GridSearchCV");, which exhaustively searches a fixed parameter grid, these methods use adaptive search strategies to explore promising hyperparameter regions more efficiently. This is especially useful for large models such as #NormalTok("XGBoost");, #NormalTok("LightGBM");, and neural networks, where exhaustive grid search may become computationally expensive.

Many modern tuning frameworks are related to ideas from Bayesian optimization. In practice, these methods often attempt to use information from previous trials to guide future searches toward more promising regions of the parameter space.

We only briefly mention these topics here since they have become mainstream tools in modern machine learning workflows:

- Bayesian optimization
- TPE (Tree-structured Parzen Estimator)
- acquisition functions
- Gaussian process optimization
- AutoML systems

A full discussion of topics is beyond the scope of this course.

]
, 
title: 
[
Modern hyperparameter tuning
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Example: XGBoost on the Diabetes Data
<example-xgboost-on-the-diabetes-data>
We now use the diabetes regression dataset from #NormalTok("sklearn"); introduced earlier. The response is a quantitative measure of disease progression one year after baseline.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.datasets ");#ImportTok("import");#NormalTok(" load_diabetes");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],
[],
[#NormalTok("X, y ");#OperatorTok("=");#NormalTok(" load_diabetes(return_X_y");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("X_train, X_test, y_train, y_test ");#OperatorTok("=");#NormalTok(" train_test_split(X, y, test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
]
In general you should not touch test sets. However in this example for simplicity we ambuse it by using test sets as validation sets.

=== Baseline model
<baseline-model>
We first build a baseline model, with all default hyperparameters.

#Skylighting(([#ImportTok("from");#NormalTok(" xgboost ");#ImportTok("import");#NormalTok(" XGBRegressor");],
[],
[#NormalTok("xgb_baseline ");#OperatorTok("=");#NormalTok(" XGBRegressor(random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("xgb_baseline.fit(X_train, y_train)");],
[#NormalTok("xgb_baseline.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.12475668653462724");],));
=== #NormalTok("RandomSearchCV");
<randomsearchcv-1>
The first round we use random search to try to find a good enough point. Note that we choose a relatively large #NormalTok("n_estimators"); which we will tune in the next early stopping stage.

#Skylighting(([#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" randint, uniform");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" RandomizedSearchCV");],
[],
[#NormalTok("param_distributions ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": randint(");#DecValTok("2");#NormalTok(", ");#DecValTok("8");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": uniform(");#FloatTok("0.01");#NormalTok(", ");#FloatTok("0.19");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": uniform(");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.4");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": uniform(");#FloatTok("0.6");#NormalTok(", ");#FloatTok("0.4");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("10");#NormalTok("),");],
[#NormalTok("}");],
[],
[#NormalTok("random_search ");#OperatorTok("=");#NormalTok(" RandomizedSearchCV(");],
[#NormalTok("    XGBRegressor(n_estimators");#OperatorTok("=");#DecValTok("2000");#NormalTok(", random_state");#OperatorTok("=");#DecValTok("1");#NormalTok(", n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    param_distributions");#OperatorTok("=");#NormalTok("param_distributions,");],
[#NormalTok("    n_iter");#OperatorTok("=");#DecValTok("20");#NormalTok(",");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("random_search.fit(X_train, y_train)");],
[#NormalTok("random_search.best_params_");],));
#Skylighting(([#NormalTok("{'colsample_bytree': np.float64(0.8650107467800177),");],
[#NormalTok(" 'learning_rate': np.float64(0.012578610766300869),");],
[#NormalTok(" 'max_depth': 3,");],
[#NormalTok(" 'reg_lambda': np.float64(8.379449074988038),");],
[#NormalTok(" 'subsample': np.float64(0.6384393631575852)}");],));
The purpose of this random search is to find a rough range of the best combination in order for the refined grid search. According to the result, we may construct a smaller range for refined grid search.

#block[
#Skylighting(([#NormalTok("param_grid_refined ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.008");#NormalTok(", ");#FloatTok("0.0125");#NormalTok(", ");#FloatTok("0.018");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": [");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": [");#FloatTok("0.55");#NormalTok(", ");#FloatTok("0.64");#NormalTok(", ");#FloatTok("0.72");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": [");#FloatTok("0.80");#NormalTok(", ");#FloatTok("0.87");#NormalTok(", ");#FloatTok("0.95");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": [");#FloatTok("5.0");#NormalTok(", ");#FloatTok("8.5");#NormalTok(", ");#FloatTok("12.0");#NormalTok("],");],
[#NormalTok("}");],));
]
=== Early stopping
<early-stopping-1>
Before we run the refined grid search, we need to determine the #NormalTok("n_estimators"); using early stopping.

#Skylighting(([#NormalTok("X_tr, X_val, y_tr, y_val ");#OperatorTok("=");#NormalTok(" train_test_split(");],
[#NormalTok("    X_train,");],
[#NormalTok("    y_train,");],
[#NormalTok("    test_size");#OperatorTok("=");#FloatTok("0.2");#NormalTok(",");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok(")");],
[#NormalTok("xgb_es ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#DecValTok("3000");#NormalTok(",");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("random_search.best_params_,");],
[#NormalTok("    early_stopping_rounds");#OperatorTok("=");#DecValTok("50");#NormalTok(",  ");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[#NormalTok("xgb_es.fit(X_tr, y_tr, eval_set");#OperatorTok("=");#NormalTok("[(X_val, y_val)], verbose");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok("best_round ");#OperatorTok("=");#NormalTok(" xgb_es.best_iteration ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("best_round ");],));
#Skylighting(([#NormalTok("281");],));
=== Refined grid search
<refined-grid-search>
Now we can run refined grid search using #NormalTok("n_estimators=best_round"); (which is 281 in this example).

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" GridSearchCV");],
[],
[#NormalTok("xgb_base ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid_refined ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.008");#NormalTok(", ");#FloatTok("0.0125");#NormalTok(", ");#FloatTok("0.018");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": [");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": [");#FloatTok("0.55");#NormalTok(", ");#FloatTok("0.64");#NormalTok(", ");#FloatTok("0.72");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": [");#FloatTok("0.80");#NormalTok(", ");#FloatTok("0.87");#NormalTok(", ");#FloatTok("0.95");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": [");#FloatTok("5.0");#NormalTok(", ");#FloatTok("8.5");#NormalTok(", ");#FloatTok("12.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid_search ");#OperatorTok("=");#NormalTok(" GridSearchCV(xgb_base, param_grid");#OperatorTok("=");#NormalTok("param_grid_refined, cv");#OperatorTok("=");#DecValTok("5");#NormalTok(", n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("grid_search.fit(X_train, y_train)");],));
]
Sometimes a full refined grid search is still computationally expensive. In this case, a common practical strategy is to tune the hyperparameters in stages.

#block[
#callout(
body: 
[
#Skylighting(([#NormalTok("xgb_base ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid_1 ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("]");],
[#NormalTok("}");],
[],
[#NormalTok("grid_1 ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    xgb_base,");],
[#NormalTok("    param_grid");#OperatorTok("=");#NormalTok("param_grid_1,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("grid_1.fit(X_train, y_train)");],
[#NormalTok("grid_1.best_params_");],));
#Skylighting(([#NormalTok("{'max_depth': 1}");],));
]
, 
title: 
[
Stage 1: tune tree complexity
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#NormalTok("xgb_stage2 ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round, random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(", n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(", ");#OperatorTok("**");#NormalTok("grid_1.best_params_");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid_2 ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"learning_rate\"");#NormalTok(": [");#FloatTok("0.035");#NormalTok(", ");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.07");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid_2 ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    xgb_stage2,");],
[#NormalTok("    param_grid");#OperatorTok("=");#NormalTok("param_grid_2,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("grid_2.fit(X_train, y_train)");],
[#NormalTok("grid_2.best_params_");],));
#Skylighting(([#NormalTok("{'learning_rate': 0.07}");],));
]
, 
title: 
[
Stage 2: tune learning rate around the selected number of trees
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#NormalTok("xgb_stage3 ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_1.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_2.best_params_,");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid_3 ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"subsample\"");#NormalTok(": [");#FloatTok("0.60");#NormalTok(", ");#FloatTok("0.66");#NormalTok(", ");#FloatTok("0.75");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"colsample_bytree\"");#NormalTok(": [");#FloatTok("0.85");#NormalTok(", ");#FloatTok("0.90");#NormalTok(", ");#FloatTok("0.95");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid_3 ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    xgb_stage3,");],
[#NormalTok("    param_grid");#OperatorTok("=");#NormalTok("param_grid_3,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("grid_3.fit(X_train, y_train)");],
[#NormalTok("grid_3.best_params_");],));
#Skylighting(([#NormalTok("{'colsample_bytree': 0.85, 'subsample': 0.75}");],));
]
, 
title: 
[
Stage 3: tune sampling parameters
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#Skylighting(([#NormalTok("xgb_stage4 ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_1.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_2.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_3.best_params_,");],
[#NormalTok(")");],
[],
[#NormalTok("param_grid_4 ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"reg_lambda\"");#NormalTok(": [");#FloatTok("2.0");#NormalTok(", ");#FloatTok("3.25");#NormalTok(", ");#FloatTok("5.0");#NormalTok("],");],
[#NormalTok("}");],
[],
[#NormalTok("grid_4 ");#OperatorTok("=");#NormalTok(" GridSearchCV(");],
[#NormalTok("    xgb_stage4,");],
[#NormalTok("    param_grid");#OperatorTok("=");#NormalTok("param_grid_4,");],
[#NormalTok("    cv");#OperatorTok("=");#DecValTok("5");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok(")");],
[],
[#NormalTok("grid_4.fit(X_train, y_train)");],
[#NormalTok("grid_4.best_params_");],));
#Skylighting(([#NormalTok("{'reg_lambda': 2.0}");],));
]
, 
title: 
[
Stage 4: tune regularization
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Finally we put all hyperparameters together for a final training.

#Skylighting(([#NormalTok("best_params ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_1.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_2.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_3.best_params_,");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("grid_4.best_params_,");],
[#NormalTok("}");],
[],
[#NormalTok("final_model ");#OperatorTok("=");#NormalTok(" XGBRegressor(");],
[#NormalTok("    n_estimators");#OperatorTok("=");#NormalTok("best_round,");],
[#NormalTok("    random_state");#OperatorTok("=");#DecValTok("0");#NormalTok(",");],
[#NormalTok("    n_jobs");#OperatorTok("=-");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    ");#OperatorTok("**");#NormalTok("best_params,");],
[#NormalTok(")");],
[],
[#NormalTok("final_model.fit(X_train, y_train)");],
[#NormalTok("final_model.score(X_test, y_test)");],));
#Skylighting(([#NormalTok("0.415029538595333");],));
It doesn't have to be exactly the same as the full grid search result. However the result will be very similar.

=== Feature Importance
<feature-importance-2>
XGBoost provides impurity-like feature importance through #NormalTok(".feature_importances_");. Conceptually, this is similar to MDI in Random Forests since both measure how much a feature improves the training objective during tree construction.

However, they are not exactly the same. In Random Forests, MDI is based on reductions in RSS or Gini impurity, while in XGBoost the gain is computed from reductions in the regularized boosting objective.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#NormalTok("importance ");#OperatorTok("=");#NormalTok(" pd.Series(final_model.feature_importances_).sort_values(ascending");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("7");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("importance.plot(kind");#OperatorTok("=");#StringTok("\"barh\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"feature importance\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"XGBoost Feature Importance\"");#NormalTok(")");],));
#Skylighting(([#NormalTok("Text(0.5, 1.0, 'XGBoost Feature Importance')");],));
#block[
#box(image("contents\\2/boost_files/figure-typst/cell-32-output-2.svg"))

]
Feature importance describes how much the fitted model uses each predictor for prediction. It should not be interpreted as a causal effect.

#show: appendices.with("Appendices", hide-parent: true)
#heading(level: 1, numbering: none)[Appendices]
= Python IDE Setup
<python-ide-setup>
There are many ways to set up a Python development environment, and each has its own advantages and disadvantages. In this tutorial, we will cover one of the most popular current setups: VS Code + #NormalTok("uv");.

For now, we will focus only on the practical setup steps. The underlying concepts will be discussed in the later appendices.

This tutorial uses Windows 11. If you use another operating system, the steps are very similar, but you may need to make some minor but straightforward modifications. If you encounter major issues, please contact me.

== VS Code
<sec-vscode>
We choose VS Code as our IDE for Python. The installation is straightforward starting from the #link("https://code.visualstudio.com/")[Official website]. After installation, we need to do a few configurations to make the experience better.

+ For development of Python, the essential plugins are the Python plugin and Jupyter plugin. You only need to install the two main ones, and all related plugins will be installed automatically.

#box(image("contents\\app/assests/img/20250811114515.png"))

You may either search the extensions directly from VS Code extension tab (which is usually located on the left side bar), or you may install it from the link #link("https://marketplace.visualstudio.com/items?itemName=ms-python.python")[python] and #link("https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter")[jupyter].

#block[
#set enum(numbering: "1.", start: 2)
+ Sometimes you may need to use the terminal inside VS Code. You may start the terminal from top menu (whose hotkey is by default #NormalTok("ctrl+shift+`");).
]

#box(image("contents\\app/assests/img/20250811113649.png"))

Note that there are many different choices of terminals. After you start the first default terminal, you may start any new terminals using the small #NormalTok("+"); and the #NormalTok("v"); mark on the right.

#box(image("contents\\app/assests/img/20250811120220.png"))

#block[
#callout(
body: 
[
In Windows the default terminal is Powershell when you first install VS Code. In the past it had bugs with #NormalTok("conda"); (and I don't know whether it is fixed now). In order to avoid headaches due to the bugs, we simply switch to other terminals, like Command Prompt. You may change the default terminal by

+ Press #NormalTok("Ctrl+Shift+P"); or #NormalTok("F1"); to open the top prompt menu.
+ Find the #NormalTok("Terminal: Select Default Profile"); command.

#box(image("contents\\app/assests/img/20250811114818.png"))

#block[
#set enum(numbering: "1.", start: 3)
+ Select the desired terminal as the default one.
]

#box(image("contents\\app/assests/img/20250811114921.png"))

]
, 
title: 
[
Change Terminal default profile
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
== Python Virtual Environment installation
<python-virtual-environment-installation>
There are many tools available for managing Python environments and packages. As of Summer 2026, #NormalTok("uv"); has become one of the most popular choices.

#NormalTok("uv"); is an all-in-one tool for managing Python installations, virtual environments, and project dependencies. With #NormalTok("uv");, you do not need to install Python separately, as it can download and manage Python versions for you. You may visit the #link("https://docs.astral.sh/uv/getting-started/installation/")[official documentation] to install #NormalTok("uv");.

After installation (and you may need to restart VS Code or open a new terminal window so that the #NormalTok("uv"); command becomes available), you can use the following commands to verify that #NormalTok("uv"); is working correctly.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Command], [Purpose], [Example Output],),
  table.hline(),
  [#NormalTok("uv --version");], [Display the installed #NormalTok("uv"); version. Useful for verifying that #NormalTok("uv"); is installed correctly.], [#NormalTok("uv 0.11.17");],
  [#NormalTok("uv self update");], [Update #NormalTok("uv"); itself to the latest available version. Similar to updating package managers such as #NormalTok("pip"); or #NormalTok("cargo");.], [#NormalTok("Upgraded uv from v0.11.4 to v0.11.17!");],
  [#NormalTok("uv python list");], [Show all Python versions available locally and those that can be installed through #NormalTok("uv");.], [Lists installed and downloadable Python versions.],
)
Since VS Code often expects to discover at least one Python interpreter before it can fully initialize its Python and Jupyter services, we first install a Python version managed by #NormalTok("uv");.

#Skylighting(([#ExtensionTok("uv");#NormalTok(" python install");],));
This Python installation is managed entirely by #NormalTok("uv");\; it is not intended to be used directly for course work. Instead, it serves as a bootstrap interpreter that allows VS Code to detect Python correctly and manage project-specific virtual environments more reliably. You can verify the installed Python versions using #NormalTok("uv python list"); as mentioned above.

=== Setup the environment for the course
<setup-the-environment-for-the-course>
To set up the environment for this course, we provide the #link("../../pyproject.toml")[toml file] and #link("../../.python-version")[python version file] for this course.

#Skylighting(([#KeywordTok("[project]");],
[#DataTypeTok("name");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"STAT432\"");],
[#DataTypeTok("version");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"0.1.0\"");],
[#DataTypeTok("requires-python");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\">=3.13\"");],
[#DataTypeTok("dependencies");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");],
[#NormalTok("    ");#StringTok("\"jupyter>=1.1.1\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"matplotlib>=3.10.9\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"openpyxl>=3.1.5\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"pandas>=3.0.2\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"scikit-learn>=1.8.0\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"seaborn>=0.13.2\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"statsmodels>=0.14.6\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"xgboost>=3.2.0\"");#OperatorTok(",");],
[#OperatorTok("]");],));
The python version file only contains the version number #NormalTok("3.13"); inside since this is the version of Python I use when I wrote the notes. You may either download the file and put it inside the folder or create a file with the name #NormalTok(".python-version"); and write #NormalTok("3.13"); inside.

#block[
#callout(
body: 
[
Before proceeding, make sure the file is saved.

By default, VS Code does not enable Auto Save. If you see a small dot next to the file name, the file contains unsaved changes.

#box(image("contents\\app/assets/img/20260529122024.png"))

Many beginner problems occur because they modify a file but forget to save it before running commands.

]
, 
title: 
[
Autosave
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
+ Create a new folder. The folder name is irrelevant. Put the files #NormalTok("pyproject.toml"); and #NormalTok(".python-version"); in the folder.
+ Open a terminal (no matter whether within VS Code or not) and enter the folder. Use the command #NormalTok("uv sync");.

After the command finishes, #NormalTok("uv"); creates a virtual environment named #NormalTok(".venv"); and installs all required packages specified in #NormalTok("pyproject.toml");. The resulting environment should closely match the one used to prepare these notes.

Now it is possible to start using the virtual environment for the course. In case that you need to modify the virtual environment, please continue the read the following optional part.

#block[
#callout(
body: 
[
A Jupyter kernel is the Python environment used by a notebook. When a notebook cell is executed, the code runs inside the selected kernel. For this reason, it is important to connect the notebook to the kernel associated with your course virtual environment.

Modern versions of VS Code can often detect a virtual environment automatically and use it directly as a notebook kernel without requiring you to manually register a Jupyter kernel using #NormalTok("ipykernel"); install. Therefore if everything works well the actions before this note is enough.

However, there are situations in which you may need to create a dedicated Jupyter kernel manually. In addition, you may occasionally need to modify the virtual environment by installing additional packages. Therefore, it is useful to understand these operations.

+ Activate the virvutal environment.

#Skylighting(([#CommentTok("# Windows");],
[#ExtensionTok(".venv\\Scripts\\activate");],
[],
[#CommentTok("# Linux / macOS");],
[#BuiltInTok("source");#NormalTok(" .venv/bin/activate");],));
#block[
#set enum(numbering: "1.", start: 2)
+ After activation, your terminal prompt will typically change to something like indicating that the virtual environment is active:
]

#Skylighting(([#CommentTok("# Windows");],
[#KeywordTok("(");#ExtensionTok("stat432");#KeywordTok(")");#NormalTok(" ");#ExtensionTok("C:\\Users\\yourname\\project");#OperatorTok(">");],
[],
[#CommentTok("# Linux / macOS");],
[#KeywordTok("(");#ExtensionTok("stat432");#KeywordTok(")");#NormalTok(" ");#ExtensionTok("user@computer:~/project$");],));
Note that the name #NormalTok("stat432"); is indicated in the #NormalTok("pyproject.toml"); that #NormalTok("name = \"STAT432\"");. It doesn't do anything special if you don't publish this environment. It is different from the jupyter kernel name.

#block[
#set enum(numbering: "1.", start: 3)
+ You may use #NormalTok("where python"); (Windows) or #NormalTok("which python"); (Linux / macOS) to see whether the correct python version is activated. The path should be #NormalTok(".venv"); in the current folder.
+ To install an additional package and update the project configuration, use
]

#Skylighting(([#ExtensionTok("uv");#NormalTok(" add ");#OperatorTok("<");#NormalTok("package name");#OperatorTok(">");],));
More commands can be found in #link("https://docs.astral.sh/uv/getting-started/")[#NormalTok("uv"); official document].

#block[
#set enum(numbering: "1.", start: 5)
+ If you need to create a dedicated Jupyter kernel, run
]

#Skylighting(([#ExtensionTok("python");#NormalTok(" ");#AttributeTok("-m");#NormalTok(" ipykernel install ");#AttributeTok("--user");#NormalTok(" ");#AttributeTok("--name");#NormalTok(" stats ");#AttributeTok("--display-name");#NormalTok(" ");#StringTok("\"(stats)\"");],));
Note that #NormalTok("--name stats"); specifies the kernel identifier. In this example the identifier is #NormalTok("stats");, but you may choose any name that is easy for you to recognize. Later, when selecting a kernel in Jupyter or VS Code, this identifier is used internally to distinguish one kernel from another, so it should be unique on your system.

The option #NormalTok("--display-name \"(stats)\""); specifies the name displayed in Jupyter and VS Code when selecting a kernel. Unlike #NormalTok("--name");, the display name does not need to be unique, although choosing a descriptive name is recommended.

]
, 
title: 
[
Jupyter kernels and modifying venv
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Back to VS Code and start Jupyter notebook
<back-to-vs-code-and-start-jupyter-notebook>
After Python is installed and virtual environment is set up, we could start to do a Hello World project.

The way VS Code organizes projects is through folders by default. So we first start a new folder (called the working folder) and all project related files should be put inside this folder. (There are ways to work with files outside the working folder, but you don't need it in most cases.)

Since we already set up a folder (with a virtual environment), we open it as our working folder.

#box(image("contents\\app/assests/img/20250811124111.png"))

The folder already contains the project files and the environment files. You may see them from the file explorer.

#box(image("contents\\app/assets/img/20260529132900.png"))

Then you may create new files/folders or copy files/folders into this working folder. For demonstration a new file called #NormalTok("helloworld.ipynb"); is created.

#box(image("contents\\app/assets/img/20260529133205.png"))

#NormalTok("ipynb"); means this is a Jupyter notebook file (which is short for #NormalTok("interactive Python notebook");). This is the format for this course's homework assignment.

This is the appearance of an empty notebook file.

#box(image("contents\\app/assets/img/20260529133321.png"))

We attach the kernel we just created to this notebook. Click the #NormalTok("Select Kernel"); / #NormalTok("Detecting Kernels"); on the right upper corner and select the environment we want.

#box(image("contents\\app/assets/img/20260529150001.png"))

- If you created a new Jupyter kernel, you can find it from #NormalTok("Jupyter kernel...");.
- If not, you can find your virtual environement in the working folder from #NormalTok("Python Environments...");.

#box(image("contents\\app/assets/img/20260530232943.png"))

After the kernel is selected, we could start using the notebook. I prefer to use the following code as hello world. It can also tell us whether the correct python is used.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" sys");],
[#BuiltInTok("print");#NormalTok("(sys.executable)");],));
]
#box(image("contents\\app/assets/img/20260530233118.png"))

== Quick Markdown syntax
<quick-markdown-syntax>
Now we can start using a notebook. One of the best features of a notebook is that it can combine code, narrative text, and output in a single file.

There are two types of cells in a notebook: Code cells and Markdown cells.

- Code cells are used to run Python code.
- Markdown cells are used to write text, explanations, equations, and documentation.

In statistical learning, code cells are typically used for data analysis, model fitting, and computations, while Markdown cells are used to explain the methods, interpret the results, and document the workflow.

#box(image("contents\\app/assets/img/20260530234530.png"))

A notebook combines code, output, and narrative in a single document, making it an ideal environment for data science and machine learning.

#block[
#callout(
body: 
[
You can always click the small #NormalTok("Edit"); / #NormalTok("Stop Editing"); button to preview how your text will be rendered.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#box(image("contents\\app/assets/img/20260530233822.png"))

#box(image("contents\\app/assets/img/20260530233847.png"))

Markdown is a lightweight text format. In this course, we will use only the most basic Markdown syntax.

=== Text Formatting
<text-formatting>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Markdown Syntax], [Output],),
  table.hline(),
  [#Skylighting(([#NormalTok("*italics*, **bold**, ***bold italics***");],));], [#emph[italics], #strong[bold], #strong[#emph[bold italics]]],
  [#Skylighting(([#NormalTok("superscript^2^ / subscript~2~");],));], [superscript#super[2] / subscript#sub[2]],
  [#Skylighting(([#NormalTok("~~strikethrough~~");],));], [#strike[strikethrough]],
  [#Skylighting(([#InformationTok("`verbatim code`");],));], [#NormalTok("verbatim code");],
)
=== Headings
<headings>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Markdown Syntax], [Output],),
  table.hline(),
  [#Skylighting(([#FunctionTok("# Heading 1");],));], [#heading(level: 1, numbering: none)[Heading 1]
  <heading-1>],
  [#Skylighting(([#FunctionTok("## Heading 2");],));], [#heading(level: 2, numbering: none)[Heading 2]
  <heading-2>],
  [#Skylighting(([#FunctionTok("### Heading 3");],));], [#heading(level: 3, numbering: none)[Heading 3]
  <heading-3>],
)
#block[
#callout(
body: 
[
Note that for heading, there is a space after #NormalTok("#");.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Lists
<lists>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Markdown Syntax], [Output],),
  table.hline(),
  [#Skylighting(([#SpecialStringTok("* ");#NormalTok("unordered list");],
  [#SpecialStringTok("  + ");#NormalTok("sub-item 1");],
  [#SpecialStringTok("  + ");#NormalTok("sub-item 2");],
  [#SpecialStringTok("    - ");#NormalTok("sub-sub-item 1");],));], [- unordered list
    - sub-item 1
    - sub-item 2
      - sub-sub-item 1

  ],
  [#Skylighting(([#SpecialStringTok("1. ");#NormalTok("ordered list");],
  [#SpecialStringTok("2. ");#NormalTok("item 2");],
  [#NormalTok("   i) sub-item 1");],
  [#NormalTok("      A.  sub-sub-item 1");],));], [+ ordered list
  + item 2
    #block[
    #set enum(numbering: "i)", start: 1)
    + sub-item 1
      #block[
      #set enum(numbering: "A.", start: 1)
      + sub-sub-item 1
      ]
    ]

  ],
)
#block[
#callout(
body: 
[
Note that for lists, there is a space after #NormalTok(".");.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Essential LaTeX
<essential-latex>
Use single dollar signs for inline math:

#Skylighting(([#NormalTok("The fitted value is $\\hat y_i$.");],));
#quote(block: true)[
The fitted value is $hat(y)_i$.
]

Use double dollar signs for displayed equations:

#Skylighting(([#NormalTok("$$");],
[#NormalTok("Y = \\beta_0 + \\beta_1 X + \\epsilon.");],
[#NormalTok("$$");],));
$ Y = beta_0 + beta_1 X + epsilon.alt . $

Common symbols:

#Skylighting(([#NormalTok("$\\hat y$        predicted value");],
[#NormalTok("$\\bar x$        sample mean");],
[#NormalTok("$\\beta_0$       coefficient");],
[#NormalTok("$X^\\top X$      transpose");],
[#NormalTok("$\\sum_{i=1}^n$  summation");],));
#quote(block: true)[
$hat(y)$: predicted value

$macron(x)$: sample mean

$beta_0$: coefficient

$X^top X$: transpose

$sum_(i = 1)^n$: summation
]

LaTeX supports a wide range of mathematical notation, but the basic symbols introduced here will be enough for all of the work in this course.

= Python Basics for #NormalTok("sklearn");
<python-basics-for-sklearn>
This note introduces only the Python syntax needed for the rest of these notes. The goal is not to cover Python as a full programming language. The goal is to make code using #NormalTok("numpy");, #NormalTok("matplotlib");, and #NormalTok("sklearn"); readable.

== Running Python Code
<running-python-code>
A Python code chunk looks like this:

#Skylighting(([#CommentTok("# This is a comment");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" ");#DecValTok("10");#NormalTok("      ");#CommentTok("# assignment uses =");],
[],
[#NormalTok("a, b ");#OperatorTok("=");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");],
[#NormalTok("a ");#OperatorTok("+");#NormalTok(" b       ");#CommentTok("# last expression is automatically displayed");],));
#Skylighting(([#NormalTok("5");],));
#block[
#callout(
body: 
[
+ When a code cell is executed, the value of the last expression is automatically displayed. Any explicit output commands, such as #NormalTok("print()");, will also produce output.

+ Use #NormalTok("#"); comments only for short notes that help explain the code. Detailed explanations and discussion should be written in Markdown cells, where they are easier to read and maintain.

]
, 
title: 
[
Notebook
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Indentation
<indentation>
Python uses indentation to mark code blocks. R uses braces #NormalTok("{}");\; Python uses indentation.

For example, a #NormalTok("for"); loop:

#block[
#Skylighting(([#ControlFlowTok("for");#NormalTok(" k ");#KeywordTok("in");#NormalTok(" [");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("5");#NormalTok("]:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(k)");],));
#block[
#Skylighting(([#NormalTok("1");],
[#NormalTok("3");],
[#NormalTok("5");],));
]
]
The indented block belongs to the loop. These notes use loops only when they are helpful for plotting or comparing models.

=== #NormalTok("if"); and #NormalTok("for");
<if-and-for>
The logic of #NormalTok("if"); statements and #NormalTok("for"); loops is straightforward. When using them, pay attention to indentation. A colon #NormalTok(":"); indicates the beginning of an indented code block.

#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");],
[#ControlFlowTok("if");#NormalTok(" x ");#OperatorTok("==");#NormalTok(" ");#DecValTok("2");#NormalTok(":");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("'good'");#NormalTok(")");],
[#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#StringTok("'not good'");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("not good");],));
]
]
#block[
#Skylighting(([#ControlFlowTok("for");#NormalTok(" k ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("4");#NormalTok("):");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(k)");],));
#block[
#Skylighting(([#NormalTok("0");],
[#NormalTok("1");],
[#NormalTok("2");],
[#NormalTok("3");],));
]
]
=== Functions and Objects
<functions-and-objects>
This is not an object-oriented programming course, so don't worry too much about the details. The important idea is the distinction between a function, a class, and an object created from a class.

- Function: performs an action and returns a result. Called with parentheses: #NormalTok("round(3.14, 2)");
- Class: a blueprint for creating objects.
- Object: stores information and provides methods. Accessed with a dot: #NormalTok("object.method()");

Example in scikit-learn:

#Skylighting(([#NormalTok("model ");#OperatorTok("=");#NormalTok(" LinearRegression()");],));
Here

- #NormalTok("LinearRegression"); is the class;
- #NormalTok("LinearRegression()"); creates a linear regression model object;
- the object is assigned to the variable #NormalTok("model");.

#Skylighting(([#NormalTok("model.fit(X_train, y_train)");],
[#NormalTok("coef ");#OperatorTok("=");#NormalTok(" model.coef_");],));
Here

- #NormalTok("fit()"); is method;
- #NormalTok("coef_"); stores information about the fitted model;
- methods are called using #NormalTok("object.method(...)");\;
- stored information is accessed using #NormalTok("object.attribute");.

In almost all #NormalTok("scikit-learn"); code, you should work with objects rather than classes. A common mistake is to pass a class where an object is required.

#Skylighting(([#NormalTok("pipe ");#OperatorTok("=");#NormalTok(" make_pipeline(StandardScaler, LinearRegression)     ");#CommentTok("# wrong");],
[#NormalTok("pipe ");#OperatorTok("=");#NormalTok(" make_pipeline(StandardScaler(), LinearRegression()) ");#CommentTok("# correct");],));
The same idea applies to most #NormalTok("scikit-learn"); components, including transformers, models, and pipelines. In general, if something is used as a step in a pipeline, you should create an object by adding #NormalTok("()");.

#block[
#callout(
body: 
[
The meaning of #NormalTok("."); is different in Python and R.

- In Python, #NormalTok("."); is used to access methods and attributes of an object.

#Skylighting(([#NormalTok("model.fit(X, y)");],
[#NormalTok("model.coef_");],));
- In R, #NormalTok("."); is usually just part of a variable or function name.

#Skylighting(([#NormalTok("my.variable ");#OtherTok("<-");#NormalTok(" ");#DecValTok("1");],));
Do not interpret dots in R names as object access.

]
, 
title: 
[
#NormalTok("."); (Dot)
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
=== Importing Packages
<importing-packages>
Python packages are loaded with #NormalTok("import");.

The usual imports in these notes are:

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
The names on the right are aliases:

- #NormalTok("numpy"); is used as #NormalTok("np");\;
- #NormalTok("pandas"); is used as #NormalTok("pd");\;
- #NormalTok("matplotlib.pyplot"); is used as #NormalTok("plt");.

After importing a package this way, you access its functions using the package name, e.g.

- #NormalTok("np.array([1, 2, 3])");
- #NormalTok("pd.DataFrame({\"x\": [1, 2, 3]})");
- #NormalTok("plt.plot([1, 2, 3], [4, 5, 6])");

#block[
#callout(
body: 
[
When a package is imported with #NormalTok("import ... as ...");, you must use the alias to access its functions and classes instead of the original name.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Sometimes only specific functions or classes are imported.

#block[
#Skylighting(([#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LinearRegression");],
[#ImportTok("from");#NormalTok(" sklearn.model_selection ");#ImportTok("import");#NormalTok(" train_test_split");],));
]
These objects can then be used directly.

#block[
#Skylighting(([#NormalTok("model ");#OperatorTok("=");#NormalTok(" LinearRegression()");],));
]
#block[
#callout(
body: 
[
After #NormalTok("from sklearn.linear_model import LinearRegression");, you may use #NormalTok("LinearRegression()"); directly, but other objects from #NormalTok("sklearn.linear_model"); are not automatically imported.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Data structure
<data-structure>
=== Basic Objects
<basic-objects>
Python has several basic data types.

#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" ");#DecValTok("3");#NormalTok("          ");#CommentTok("# integer");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" ");#FloatTok("2.5");#NormalTok("        ");#CommentTok("# float");],
[#NormalTok("name ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"tree\"");#NormalTok("  ");#CommentTok("# string");],
[#NormalTok("flag ");#OperatorTok("=");#NormalTok(" ");#VariableTok("True");#NormalTok("    ");#CommentTok("# Boolean");],));
]
Use #NormalTok("type()"); to check the type of an object.

#Skylighting(([#BuiltInTok("type");#NormalTok("(y)");],));
#Skylighting(([#NormalTok("float");],));
Python is case-sensitive. #NormalTok("x"); and #NormalTok("X"); are different objects.

=== Lists
<lists-1>
A list is an #strong[ordered collection] of objects. Lists are commonly used to store variable names, column names, or collections of parameter values.

#table(
  columns: (18.9%, 33.86%, 47.24%),
  align: (auto,auto,auto,),
  table.header([Purpose], [Example], [Explanation],),
  table.hline(),
  [Create a list], [#NormalTok("features = [\"age\", \"income\", \"education\"]");], [Creates a list containing three strings.],
  [Access the first element], [#NormalTok("features[0]");], [Returns #NormalTok("\"age\"");. Python indexing starts at #NormalTok("0");.],
  [Access the last element], [#NormalTok("features[-1]");], [Returns #NormalTok("\"education\"");. Negative indices count from the end.],
  [Select several elements], [#NormalTok("features[0:2]");], [Returns #NormalTok("[\"age\", \"income\"]");. The stop index is not included.],
  [Add an element], [#NormalTok("features.append(\"gender\")");], [Adds #NormalTok("\"gender\""); to the end of the list.],
  [Count elements], [#NormalTok("len(features)");], [Returns the number of elements in the list.],
)
#block[
#callout(
body: 
[
Unlike R, Python uses zero-based indexing, so the first element has index #NormalTok("0");.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Dictionaries
<dictionaries>
A dictionary stores #strong[key-value pairs]. It is similar to a named list in R and is commonly used to store settings, options, and model parameters.

#table(
  columns: (16.8%, 40.8%, 42.4%),
  align: (auto,auto,auto,),
  table.header([Purpose], [Example], [Explanation],),
  table.hline(),
  [Create a dictionary], [#NormalTok("params = {\"n_neighbors\": 5, \"weights\": \"uniform\"}");], [Creates a dictionary with two keys and their values.],
  [Access a value], [#NormalTok("params[\"n_neighbors\"]");], [Returns #NormalTok("5");.],
  [Add or update a value], [#NormalTok("params[\"metric\"] = \"euclidean\"");], [Adds a new key-value pair or updates an existing one.],
  [Count entries], [#NormalTok("len(params)");], [Returns the number of key-value pairs.],
  [Store model settings], [#NormalTok("{\"max_depth\": 3, \"min_samples_leaf\": 5}");], [A common use in machine learning.],
  [Store parameter grids], [#NormalTok("{\"max_depth\": [2,3,4]}");], [Often used when tuning hyperparameters.],
)
A typical parameter grid in #NormalTok("scikit-learn"); looks like:

#Skylighting(([#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"max_depth\"");#NormalTok(": [");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("],");],
[#NormalTok("    ");#StringTok("\"min_samples_leaf\"");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok("],");],
[#NormalTok("}");],));
For pipelines, parameter names often use two underscores:

#Skylighting(([#NormalTok("param_grid ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("\"model__C\"");#NormalTok(": [");#FloatTok("0.1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("10");#NormalTok("],");],
[#NormalTok("}");],));
#block[
#callout(
body: 
[
In a pipeline, a parameter name of the form #NormalTok("step__parameter"); refers to a parameter inside a specific pipeline step. For example, #NormalTok("model__C"); means the parameter #NormalTok("C"); of the pipeline step named #NormalTok("\"model\"");. More terminologies will be discussed in related sections.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== #NormalTok("numpy.array");
<numpy.array>
The most important data structure for numerical computation in Python is #NormalTok("numpy.array");.

#Skylighting(([#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("])");],
[#NormalTok("x");],));
#Skylighting(([#NormalTok("array([1, 2, 3, 4])");],));
Arrays have a shape and a dimension.

#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(x.shape)");],
[#BuiltInTok("print");#NormalTok("(x.ndim)");],));
#block[
#Skylighting(([#NormalTok("(4,)");],
[#NormalTok("1");],));
]
]
So #NormalTok("x"); is a 1D array containing 4 elements.

=== 2D Arrays
<d-arrays>
A 2D array is similar to a matrix.

#Skylighting(([#NormalTok("X ");#OperatorTok("=");#NormalTok(" np.array([");],
[#NormalTok("    [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("],");],
[#NormalTok("    [");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("],");],
[#NormalTok("    [");#DecValTok("5");#NormalTok(", ");#DecValTok("6");#NormalTok("]");],
[#NormalTok("])");],
[],
[#NormalTok("X");],));
#Skylighting(([#NormalTok("array([[1, 2],");],
[#NormalTok("       [3, 4],");],
[#NormalTok("       [5, 6]])");],));
#block[
#Skylighting(([#BuiltInTok("print");#NormalTok("(X.shape)");],
[#BuiltInTok("print");#NormalTok("(X.ndim)");],));
#block[
#Skylighting(([#NormalTok("(3, 2)");],
[#NormalTok("2");],));
]
]
Here #NormalTok("X"); is a 2D array with 3 rows and 2 columns.

=== Indexing
<indexing>
Use #NormalTok("[row, column]"); indexing.

#block[
#Skylighting(([#NormalTok("X[");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("]      ");#CommentTok("# row 0, column 1");],
[#NormalTok("X[:, ");#DecValTok("0");#NormalTok("]      ");#CommentTok("# first column");],
[#NormalTok("X[");#DecValTok("1");#NormalTok(", :]      ");#CommentTok("# second row");],));
]
The symbol #NormalTok(":"); means "all indices" along that axis.

Slicing can select ranges.

#block[
#Skylighting(([#NormalTok("X[");#DecValTok("0");#NormalTok(":");#DecValTok("2");#NormalTok(", ");#DecValTok("1");#NormalTok("]      ");#CommentTok("# first 2 rows, column 1");],
[#NormalTok("X[");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(":");#DecValTok("2");#NormalTok("]      ");#CommentTok("# row 0, first 2 columns");],
[#NormalTok("X[");#DecValTok("0");#NormalTok(":");#DecValTok("2");#NormalTok(", ");#DecValTok("0");#NormalTok(":");#DecValTok("2");#NormalTok("]    ");#CommentTok("# upper-left 2x2 block");],));
]
#block[
#callout(
body: 
[
#NormalTok("X[:, 0]"); returns a 1D array with shape #NormalTok("(n,)");, not a column vector.

To obtain a column vector, use

#block[
#Skylighting(([#NormalTok("X[:, [");#DecValTok("0");#NormalTok("]]");],
[#CommentTok("# or");],
[#NormalTok("X[:, ");#DecValTok("0");#NormalTok("].reshape(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],));
]
which both have shape #NormalTok("(n, 1)");.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Common Operations
<common-operations>
Arrays support vectorized arithmetic.

#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("x ");#OperatorTok("*");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("np.mean(x)");],));
]
Operations are applied elementwise.

=== Axis-wise
<axis-wise>
Many functions accept an #NormalTok("axis="); argument.

#Skylighting(([#NormalTok("X              ");#CommentTok("# show X");],));
#Skylighting(([#NormalTok("array([[1, 2],");],
[#NormalTok("       [3, 4],");],
[#NormalTok("       [5, 6]])");],));
Computes the sum across rows:

#Skylighting(([#NormalTok("X.");#BuiltInTok("sum");#NormalTok("(axis");#OperatorTok("=");#DecValTok("0");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([ 9, 12])");],));
Computes the mean across columns:

#Skylighting(([#NormalTok("X.mean(axis");#OperatorTok("=");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([1.5, 3.5, 5.5])");],));
A useful rule:

- #NormalTok("axis=0");: operate down rows (one result per column)
- #NormalTok("axis=1");: operate across columns (one result per row)

=== Reshaping
<reshaping>
A 1D array can be converted into a matrix. Consider a 1D array

#block[
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("])");],));
]
To create a column vector:

#Skylighting(([#NormalTok("x.reshape(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([[1],");],
[#NormalTok("       [2],");],
[#NormalTok("       [3],");],
[#NormalTok("       [4]])");],));
To create a row vector:

#Skylighting(([#NormalTok("x.reshape(");#DecValTok("1");#NormalTok(", ");#OperatorTok("-");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([[1, 2, 3, 4]])");],));
The value #NormalTok("-1"); means "infer this dimension automatically."

A common pattern is

#block[
#Skylighting(([#NormalTok("test_x ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("101");#NormalTok(").reshape(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],));
]
On the other side, to flatten an array back to 1D:

#Skylighting(([#NormalTok("X.reshape(");#OperatorTok("-");#DecValTok("1");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([1, 2, 3, 4, 5, 6])");],));
#NormalTok("NumPy"); reads entries row by row and produces a one-dimensional array.

#block[
#callout(
body: 
[
Other flattening methods include #NormalTok(".ravel()"); and #NormalTok(".flatten()");. The difference is about how copy-and-view is handled. We mainly use #NormalTok(".reshape(-1)"); because it makes the resulting shape explicit.

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
One common source of bugs in statistical learning is using arrays with incorrect shapes.

In #NormalTok("scikit-learn");, predictors #NormalTok("X"); are usually stored as a 2D array and responses #NormalTok("y"); as a 1D array. Other libraries may use different conventions, and the required shapes often depend on the specific model or loss function.

When shape-related errors occur, always check the documentation of the library you are using.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Arrays versus Lists
<arrays-versus-lists>
Lists are general-purpose containers, and its addition concatenates. For example

#Skylighting(([#NormalTok("[");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("] ");#OperatorTok("+");#NormalTok(" [");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("6");#NormalTok("]");],));
#Skylighting(([#NormalTok("[1, 2, 3, 4, 5, 6]");],));
Arrays are designed for numerical computation. Its operations are align with the regular math operations. Therefore for numerical work and machine learning, use #NormalTok("numpy.array"); whenever possible.

== Random Numbers
<random-numbers>
These notes often use #NormalTok("numpy"); random number generators for simulation.

#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],
[#NormalTok("x");],));
#Skylighting(([#NormalTok("array([ 0.34558419,  0.82161814,  0.33043708, -1.30315723,  0.90535587])");],));
#block[
#callout(
body: 
[
The number #NormalTok("1"); is a seed. It makes the random output reproducible.

On a single machine, if the seed is fixed the results are supposed to be the same.

You may choose any number as the seed. You may use the same seed when you want to see the same result.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Some common random functions are:

#Skylighting(([#NormalTok("rng.normal(loc");#OperatorTok("=");#DecValTok("0");#NormalTok(", scale");#OperatorTok("=");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([ 0.44637457, -0.53695324,  0.5811181 ,  0.3645724 ,  0.2941325 ])");],));
#Skylighting(([#NormalTok("rng.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", size");#OperatorTok("=");#DecValTok("5");#NormalTok(")");],));
#Skylighting(([#NormalTok("array([0.75351311, 0.53814331, 0.32973172, 0.7884287 , 0.30319483])");],));
For a two-dimensional predictor matrix:

#Skylighting(([#NormalTok("X ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("3");#NormalTok("))");],
[#NormalTok("X.shape");],));
#Skylighting(([#NormalTok("(10, 3)");],));
== #NormalTok("pandas");
<pandas>
#NormalTok("pandas"); can be treated as a wrapper of #NormalTok("numpy.array"); which make it more readable. The complete #NormalTok("pandas"); is very complicated. Here we only mention a few very important concepts.

To import #NormalTok("pandas");, in most cases we set #NormalTok("pd"); as its alias.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],));
]
=== #NormalTok("DataFrame"); and #NormalTok("Series");
<dataframe-and-series>
In #NormalTok("pandas");, #NormalTok("DataFrame"); is the 2D data table, and #NormalTok("Series"); is the 1D column. There are many ways to create a #NormalTok("DataFrame");. Here we focus on one of them, that is to convert a #NormalTok("dict"); into a #NormalTok("DataFrame");.

#Skylighting(([#NormalTok("results ");#OperatorTok("=");#NormalTok(" {");],
[#NormalTok("    ");#StringTok("'round'");#NormalTok(": [");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("5");#NormalTok("],");],
[#NormalTok("    ");#StringTok("'score'");#NormalTok(": [");#FloatTok("0.22");#NormalTok(", ");#FloatTok("0.33");#NormalTok(", ");#FloatTok("0.44");#NormalTok(", ");#FloatTok("0.55");#NormalTok(", ");#FloatTok("0.66");#NormalTok("], ");],
[#NormalTok("    ");#StringTok("'mse'");#NormalTok(": [");#FloatTok("0.12");#NormalTok(", ");#FloatTok("0.11");#NormalTok(", ");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.09");#NormalTok(", ");#FloatTok("0.08");#NormalTok("]");],
[#NormalTok("}");],
[#NormalTok("df_res ");#OperatorTok("=");#NormalTok(" pd.DataFrame(results)");],
[#NormalTok("df_res");],));
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[round], table.cell(align: right)[score], table.cell(align: right)[mse],),
  table.hline(),
  table.cell(align: horizon)[0], [1], [0.22], [0.12],
  table.cell(align: horizon)[1], [2], [0.33], [0.11],
  table.cell(align: horizon)[2], [3], [0.44], [0.10],
  table.cell(align: horizon)[3], [4], [0.55], [0.09],
  table.cell(align: horizon)[4], [5], [0.66], [0.08],
)
A single column is a #NormalTok("Series");.

#Skylighting(([#NormalTok("df_res[");#StringTok("'score'");#NormalTok("]");],));
#Skylighting(([#NormalTok("0    0.22");],
[#NormalTok("1    0.33");],
[#NormalTok("2    0.44");],
[#NormalTok("3    0.55");],
[#NormalTok("4    0.66");],
[#NormalTok("Name: score, dtype: float64");],));
Note that similar to the #NormalTok("numpy.array"); case, if we select the column as a set (even if the set contains only 1 element), we will get a 2D object, which is a #NormalTok("DataFrame"); in this case.

#Skylighting(([#NormalTok("df_res[[");#StringTok("'score'");#NormalTok("]]");],));
#table(
  columns: 2,
  align: (auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[score],),
  table.hline(),
  table.cell(align: horizon)[0], [0.22],
  table.cell(align: horizon)[1], [0.33],
  table.cell(align: horizon)[2], [0.44],
  table.cell(align: horizon)[3], [0.55],
  table.cell(align: horizon)[4], [0.66],
)
=== Read and write files
<read-and-write-files>
In #NormalTok("scikit-learn");, predictors and responses can be stored either as #NormalTok("numpy"); arrays or as #NormalTok("pandas"); objects. Throughout this course, many examples use #NormalTok("numpy");, but most code works equally well with #NormalTok("pandas"); data structures.

When working with external datasets, a common workflow is:

+ Read the data into a #NormalTok("DataFrame");.
+ Perform data cleaning and preprocessing.
+ Extract predictors and responses.
+ Fit a statistical learning model.

Two of the most common tabular file formats are CSV files and Excel spreadsheets.

#block[
#callout(
body: 
[
CSV stands for comma-separated values. A CSV file is a plain-text file that stores tabular data using a separator between columns.

Common separators include:

- #NormalTok(","); (comma)
- #NormalTok(";"); (semicolon)
- #NormalTok("\\t"); (tab)

Consider the following file #link("example.csv")[#NormalTok("example.csv");].

#Skylighting(([#NormalTok("round   score   mse");],
[#NormalTok("1   0.220000    0.120000");],
[#NormalTok("2   0.330000    0.110000");],
[#NormalTok("3   0.440000    0.100000");],
[#NormalTok("4   0.550000    0.090000");],
[#NormalTok("5   0.660000    0.080000");],));
In Python we could use #NormalTok("pd.read_csv()"); to read it.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("'example.csv'");#NormalTok(")");],
[#NormalTok("df");],));
#table(
  columns: 2,
  align: (auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[round\\tscore\\tmse],),
  table.hline(),
  table.cell(align: horizon)[0], [1\\t0.220000\\t0.120000],
  table.cell(align: horizon)[1], [2\\t0.330000\\t0.110000],
  table.cell(align: horizon)[2], [3\\t0.440000\\t0.100000],
  table.cell(align: horizon)[3], [4\\t0.550000\\t0.090000],
  table.cell(align: horizon)[4], [5\\t0.660000\\t0.080000],
)
The result is incorrect because this file uses tab characters (#NormalTok("\\t");) rather than commas as separators.

Specify the separator explicitly:

#Skylighting(([#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("'example.csv'");#NormalTok(", sep");#OperatorTok("=");#StringTok("'");#CharTok("\\t");#StringTok("'");#NormalTok(")");],
[#NormalTok("df");],));
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[round], table.cell(align: right)[score], table.cell(align: right)[mse],),
  table.hline(),
  table.cell(align: horizon)[0], [1], [0.22], [0.12],
  table.cell(align: horizon)[1], [2], [0.33], [0.11],
  table.cell(align: horizon)[2], [3], [0.44], [0.10],
  table.cell(align: horizon)[3], [4], [0.55], [0.09],
  table.cell(align: horizon)[4], [5], [0.66], [0.08],
)
]
, 
title: 
[
CSV
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Excel spreadsheets can be read using #NormalTok("pd.read_excel()");. We provide the #link("example.xlsx")[#NormalTok("exmaple.xlsx");] as an example.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.read_excel(");#StringTok("'example.xlsx'");#NormalTok(")");],
[#NormalTok("df");],));
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header(table.cell(align: right)[], table.cell(align: right)[round], table.cell(align: right)[score], table.cell(align: right)[mse],),
  table.hline(),
  table.cell(align: horizon)[0], [1], [0.22], [0.12],
  table.cell(align: horizon)[1], [2], [0.33], [0.11],
  table.cell(align: horizon)[2], [3], [0.44], [0.10],
  table.cell(align: horizon)[3], [4], [0.55], [0.09],
  table.cell(align: horizon)[4], [5], [0.66], [0.08],
)
Unlike CSV files, Excel files are stored in a binary format. Therefore, #NormalTok("pandas"); requires an additional package called an engine to read and write them. The most commonly used engine is #NormalTok("openpyxl");.

#Skylighting(([#ExtensionTok("uv");#NormalTok(" add openpyxl");],));
In this course, #NormalTok("openpyxl"); is already included in the project's #NormalTok("pyproject.toml");, so no additional installation is required.

]
, 
title: 
[
Excel
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Writing files is similar to reading files. The main difference is that writing starts from an existing #NormalTok("DataFrame"); instead of starting from #NormalTok("pd");.

#Skylighting(([#NormalTok("df.to_csv(");#StringTok("'example2.csv'");#NormalTok(")");],
[#NormalTok("df.to_excel(");#StringTok("'example2.xlsx'");#NormalTok(")");],));
=== Relative paths
<relative-paths>
In this course, always use relative paths when reading or writing files.

A relative path starts from the current working directory rather than from the root of the file system.

Suppose your working directory is

#Skylighting(([#NormalTok("C:/Users/WDAGUtilityAccount/Project/");],));
and you have the following structure:

#Skylighting(([#NormalTok("Project/");],
[#NormalTok("├── example.csv");],
[#NormalTok("└── foldername/");],));
Then you can read and write files using:

#Skylighting(([#NormalTok("df ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("\"example.csv\"");#NormalTok(")");],
[#NormalTok("df.to_csv(");#StringTok("\"foldername/result.csv\"");#NormalTok(")");],));
Notice that neither path begins with a drive name such as #NormalTok("C:"); or #NormalTok("D:");.

If your files are stored outside the working directory, #strong[copy them into the working directory] before reading them.

#block[
#callout(
body: 
[
Although absolute paths such as

#Skylighting(([#NormalTok("pd.read_csv(");#StringTok("\"D:/Files/example.csv\"");#NormalTok(")");],));
often work on your own computer, they may fail on another computer because the file locations are different.

Using relative paths makes your code more portable and easier to share.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== #NormalTok("matplotlib"); Basics
<matplotlib-basics>
These notes use only basic #NormalTok("matplotlib");. The standard import is:

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],));
]
We provide some code examples here. Most of the commands are straightforward. Please check the #link("https://matplotlib.org/")[official document] if you need more details.

=== Scatter Plot
<scatter-plot>
#Skylighting(([#NormalTok("x ");#OperatorTok("=");#NormalTok(" np.array([");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok("])");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.array([");#FloatTok("1.1");#NormalTok(", ");#FloatTok("2.0");#NormalTok(", ");#FloatTok("2.8");#NormalTok(", ");#FloatTok("4.2");#NormalTok("])");],
[],
[#NormalTok("plt.scatter(x, y)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"y\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Scatter Plot\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\app/python_files/figure-typst/cell-40-output-1.svg"))

=== Line Plot
<line-plot>
#Skylighting(([#NormalTok("x_grid ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.pi, ");#DecValTok("200");#NormalTok(")");],
[#NormalTok("y_grid ");#OperatorTok("=");#NormalTok(" np.sin(x_grid)");],
[],
[#NormalTok("plt.plot(x_grid, y_grid)");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"sin(x)\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Line Plot\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\app/python_files/figure-typst/cell-41-output-1.svg"))

=== Scatter and Line Together
<scatter-and-line-together>
#Skylighting(([#NormalTok("rng ");#OperatorTok("=");#NormalTok(" np.random.default_rng(");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("x ");#OperatorTok("=");#NormalTok(" rng.uniform(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.pi, size");#OperatorTok("=");#DecValTok("30");#NormalTok(")");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" np.sin(x) ");#OperatorTok("+");#NormalTok(" rng.normal(scale");#OperatorTok("=");#FloatTok("0.2");#NormalTok(", size");#OperatorTok("=");#DecValTok("30");#NormalTok(")");],
[#NormalTok("x_grid ");#OperatorTok("=");#NormalTok(" np.linspace(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok(" ");#OperatorTok("*");#NormalTok(" np.pi, ");#DecValTok("200");#NormalTok(")");],
[],
[#NormalTok("plt.scatter(x, y, facecolors");#OperatorTok("=");#StringTok("\"none\"");#NormalTok(", edgecolors");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(")");],
[#NormalTok("plt.plot(x_grid, np.sin(x_grid), color");#OperatorTok("=");#StringTok("\"C1\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"x\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"y\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Data and Curve\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\app/python_files/figure-typst/cell-42-output-1.svg"))

This pattern appears often when we plot data points and a fitted curve.

=== Multiple Plots
<multiple-plots>
Use #NormalTok("plt.subplots"); for multiple panels.

#Skylighting(([#NormalTok("fig, axs ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("4");#NormalTok("))");],
[],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].scatter(x, y)");],
[#NormalTok("axs[");#DecValTok("0");#NormalTok("].set_title(");#StringTok("\"scatter\"");#NormalTok(")");],
[],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].plot(x_grid, np.sin(x_grid))");],
[#NormalTok("axs[");#DecValTok("1");#NormalTok("].set_title(");#StringTok("\"line\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\app/python_files/figure-typst/cell-43-output-1.svg"))

#block[
#callout(
body: 
[
Notice that when using an axes object, many plotting commands have different names. For example, #NormalTok("plt.title()"); becomes #NormalTok("ax.set_title()");. Therefore, you cannot always replace #NormalTok("plt"); with #NormalTok("ax"); directly. For details, consult the official documentation.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Histograms
<histograms>
#Skylighting(([#NormalTok("z ");#OperatorTok("=");#NormalTok(" rng.normal(size");#OperatorTok("=");#DecValTok("200");#NormalTok(")");],
[],
[#NormalTok("plt.hist(z, bins");#OperatorTok("=");#DecValTok("20");#NormalTok(", edgecolor");#OperatorTok("=");#StringTok("\"black\"");#NormalTok(")");],
[#NormalTok("plt.xlabel(");#StringTok("\"z\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"count\"");#NormalTok(")");],
[#NormalTok("plt.title(");#StringTok("\"Histogram\"");#NormalTok(")");#OperatorTok(";");],));
#box(image("contents\\app/python_files/figure-typst/cell-44-output-1.svg"))

== Common Errors
<common-errors>
=== One-Dimensional #NormalTok("X");
<one-dimensional-x>
The most common error is passing a one-dimensional predictor array to #NormalTok("sklearn");.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Bad], [Good],),
  table.hline(),
  [#NormalTok("x = np.array([1, 2, 3, 4])");#NormalTok("model.fit(x, y)");], [#NormalTok("X = x.reshape(-1, 1)");#NormalTok("model.fit(X, y)");],
)
=== Class Name versus Model Object
<class-name-versus-model-object>
Another common mistake is confusing an #NormalTok("sklearn"); class with an object created from that class.

For example, #NormalTok("DecisionTreeClassifier"); is the class itself.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Bad], [Good],),
  table.hline(),
  [#NormalTok("model = DecisionTreeClassifier");#NormalTok("model.fit(X_train, y_train)");], [#NormalTok("model = DecisionTreeClassifier()");#NormalTok("model.fit(X_train, y_train)");],
)
=== Mixing Lists and Arrays
<mixing-lists-and-arrays>
Use arrays for elementwise numerical operations.

#Skylighting(([#NormalTok("[");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok("] ");#OperatorTok("*");#NormalTok(" ");#DecValTok("2");],));
#Skylighting(([#NormalTok("[1, 2, 3, 1, 2, 3]");],));
Plain lists do not always behave like numerical vectors.

= Some Python concepts
<some-python-concepts>
== Language
<language>
Python is a programming language. In other words, it is a collection of syntaxes.

== Interpreters
<interpreters>
Python needs to be interpreted into codes that computers can understand. Therefore there should be some programs that translate Python scripts. These programs are called #emph[interpreters].

#NormalTok("CPython"); is the reference implementation of Python and the implementation most people use. It is written mainly in C and Python. New Python language features are normally developed and tested first in CPython.

Other implementations include #link("https://www.pypy.org/")[#NormalTok("PyPy");], #link("https://www.jython.org/")[#NormalTok("Jython");] and #link("https://ironpython.net/")[#NormalTok("IronPython");]. They are useful in specific contexts, but they do not always support the same Python versions or the same package ecosystem as CPython. For example, PyPy focuses on speed through a JIT compiler, Jython integrates with the JVM but its current stable release is Python 2.7-based, and IronPython integrates with .NET but lags behind modern CPython versions.

Since #NormalTok("CPython"); is the most widely used and best-supported implementation, it is the best choice, at least for beginners. And actually, if you have no idea about this topic, but you use Python, it is highly possible that you are using #NormalTok("CPython");.

#block[
#callout(
body: 
[
We mentioned "interpreter" here. There are mainly two types of implimentations of programming langauges: interpreters and compilers. There are also some additional types like just-in-time compilers which can be treated as combinations of the two.

Python is often described as an #emph[interpreted] language, but #NormalTok("CPython"); first compiles source code to bytecode and then executes that bytecode in the Python virtual machine. For beginners, the practical point is that Python supports an interactive workflow and does not require a separate manual compile step.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== REPL
<repl>
There are two ways to use Python interpreter. One way is to execute a Python script stored in a file. The second way is called #emph[the intereactive shell], that Python interpreter read the input from user directly, and print the result immediately. The model is like code example: prompt the user for some code, and when they've entered it, execute it in the same process. This model is often called a #link("https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop")[REPL], or #emph[Read-Eval-Print-Loop].

#emph[Shell], #emph[terminal], #emph[console] have different meanings in their original contexts. However, nowadays, especially when talking about Python intereactive shell, these terminologies are used interchangeably. They are referred to the frontend of the system. In other words, the main task for the Python intereactive shell is to handle the user inputs and communicate with the backend, which is also called a #emph[kernel]. We won't distinguish the real differences between these terminologies. The kernel will be discussed in the next section.

The standard Python REPL can usually be started with #NormalTok("python"); or #NormalTok("python3");. On Windows, #NormalTok("py"); may also be available. To quit, use #NormalTok("quit()");, #NormalTok("exit()");, #NormalTok("Ctrl+D"); on macOS/Linux, or #NormalTok("Ctrl+Z"); then #NormalTok("Enter"); on Windows.

#block[
#callout(
body: 
[
In the REPL model, the backend (evaluation) is basically handled by the Python interpreter. The frontend is dealing with the user interface. Some typically tasks include the #emph[primary/secondary prompt] and multi-line commands. The original REPL is very limited.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== #NormalTok("IPython");
<ipython>
#NormalTok("IPython"); was initially designed as an Enhanced interactive Python shell. However after many year's development, the whole #NormalTok("IPython"); project becomes too big to maintain as one single project. Therefore it is now split into many smaller projects. The two most popular projects are #NormalTok("IPython"); and #NormalTok("Jupyter");. This is called #link("https://blog.jupyter.org/the-big-split-9d7b88a031a7")[the Big Split].

The current #link("https://ipython.readthedocs.io/en/stable/overview.html")[#NormalTok("IPython");] play two fundamental roles:

- Terminal #NormalTok("IPython"); as the familiar REPL;
- The #NormalTok("IPython"); kernel (which is defined below) that provides computation and communication with the frontend interfaces, like the notebook.

The core idea in the design of #NormalTok("IPython"); is to abstract and extend the notion of a traditional REPL environment by decoupling the evaluation into its own process. We call this process a #emph[kernel]: it receives execution instructions from clients and communicates the results back to them.

This decoupling allows us to have several clients connected to the same kernel, and even allows clients and kernels to live on different machines. This two-process model is now used by most of the #NormalTok("Jupyter"); project.

You can launch the #NormalTok("IPython"); shell on the command line with the #NormalTok("ipython"); command (which similar to #NormalTok("python"); case requires #NormalTok("PATH"); configuration), and quit the shell with #NormalTok("exit");/#NormalTok("exit()");/#NormalTok("quit");/#NormalTok("quit()"); commands.

The reference Python kernel provided by #NormalTok("IPython"); is called #NormalTok("ipykernel");. With #NormalTok("ipykernel"); you may create and maintain multiple kernels.

== #NormalTok("Jupyter");
<jupyter>
#link("https://docs.jupyter.org/en/latest/projects/architecture/content-architecture.html")[#NormalTok("Jupyter");] is an ecosystem for interactive computing. It originated from the IPython Notebook project and later evolved into a language-independent platform supporting many programming languages. The name #strong[Jupyter] is inspired by #strong[Julia], #strong[Python], and #strong[R], the three languages that were central to many early data science workflows.

Today, Jupyter includes several user interfaces, such as JupyterLab, Jupyter Notebook, Jupyter Console, and QtConsole. In this course, however, the important idea is not a particular interface, but the relationship among a notebook frontend, a kernel, and the notebook file stored on disk.

A Jupyter notebook is saved as a file with extension #NormalTok(".ipynb");. Internally, the file uses a structured #NormalTok("JSON"); format that stores:

- code cells;
- Markdown cells;
- outputs;
- notebook metadata.

When you run code in a notebook, the frontend sends the code to a kernel, which executes the code and returns the results. In a Python notebook, a kernel can be viewed as a Python process running in the background. It executes code, stores variables, and communicates with the notebook interface.

Different programming languages can be supported by different kernels. For example:

- #NormalTok("ipykernel"); for Python;
- #NormalTok("IRkernel"); for R;
- #NormalTok("IJulia"); for Julia.

#block[
#callout(
body: 
[
A kernel is associated with a particular Python environment, but it is not the environment itself. For example, multiple kernels may use the same Python environment while maintaining completely separate variables and memory. Conversely, multiple notebook windows may connect to the same kernel and therefore share the same variables and computational state.

For this course, you can think of the notebook as the user interface, the kernel as the Python process that runs your code, and the #NormalTok(".ipynb"); file as the notebook document saved on disk.

]
, 
title: 
[
Kernel
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Multi-kernels setup
<multi-kernels-setup>
This section is mainly following the #link("https://ipython.readthedocs.io/en/stable/install/kernel_install.html")[official document].

To install one #NormalTok("IPython"); kernel, you may install #NormalTok("ipykernel"); in the environment. If you want to have multiple #NormalTok("IPython"); kernels for different venvs, you will need to specify unique names for the kernelspecs.

+ Activate the environment you want.
+ Install the kernel in the environment.

#Skylighting(([#ExtensionTok("uv");#NormalTok(" add ipykernel");],
[#ExtensionTok("uv");#NormalTok(" run python ");#AttributeTok("-m");#NormalTok(" ipykernel install ");#AttributeTok("--user");#NormalTok(" ");#AttributeTok("--name");#NormalTok(" myenv ");#AttributeTok("--display-name");#NormalTok(" ");#StringTok("\"Python (myenv)\"");],));
#NormalTok("--user"); means that the kernel is installed in the user's folder instead of a system folder, and it can be removed. The #NormalTok("--name"); value (in this case it is #NormalTok("myenv");) is used by Jupyter internally. These commands will overwrite any existing kernel with the same name. #NormalTok("--display-name"); is what you see in the notebook menus.

#block[
#set enum(numbering: "1.", start: 3)
+ You could use the command to find all kernels installed in your system.
]

#Skylighting(([#ExtensionTok("uv");#NormalTok(" run jupyter kernelspec list");],));
Available kernels are shown, as well as the path to the kernel configuration file #NormalTok("kernel.json");. The most important configuration is the path to the Python interpreter executatable file.

#Skylighting(([#FunctionTok("{");],
[#NormalTok(" ");#DataTypeTok("\"argv\"");#FunctionTok(":");#NormalTok(" ");#OtherTok("[");],
[#NormalTok("  ");#StringTok("\"C:");#CharTok("\\\\");#StringTok("Users");#CharTok("\\\\");#StringTok("WDAGUtilityAccount");#CharTok("\\\\");#StringTok("Project");#CharTok("\\\\");#StringTok(".venv");#CharTok("\\\\");#StringTok("Scripts");#CharTok("\\\\");#StringTok("python.exe\"");#OtherTok(",");],
[#NormalTok("  ");#StringTok("\"-Xfrozen_modules=off\"");#OtherTok(",");],
[#NormalTok("  ");#StringTok("\"-m\"");#OtherTok(",");],
[#NormalTok("  ");#StringTok("\"ipykernel_launcher\"");#OtherTok(",");],
[#NormalTok("  ");#StringTok("\"-f\"");#OtherTok(",");],
[#NormalTok("  ");#StringTok("\"{connection_file}\"");],
[#NormalTok(" ");#OtherTok("]");#FunctionTok(",");],
[#NormalTok(" ");#DataTypeTok("\"display_name\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"(myenv)\"");#FunctionTok(",");],
[#NormalTok(" ");#DataTypeTok("\"language\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"python\"");#FunctionTok(",");],
[#NormalTok(" ");#DataTypeTok("\"metadata\"");#FunctionTok(":");#NormalTok(" ");#FunctionTok("{");],
[#NormalTok("  ");#DataTypeTok("\"debugger\"");#FunctionTok(":");#NormalTok(" ");#KeywordTok("true");],
[#NormalTok(" ");#FunctionTok("},");],
[#NormalTok(" ");#DataTypeTok("\"kernel_protocol_version\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"5.5\"");],
[#FunctionTok("}");],));
Notice that the path in #NormalTok("argv"); points to the Python interpreter used by this kernel. Different kernels may point to different Python environments, or multiple kernels may point to the same environment.

#set bibliography(style: "ims.csl")

#bibliography(("reference.bib"))

