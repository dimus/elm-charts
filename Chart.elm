module Chart exposing
  ( hBar, vBar, pie, lChart
  , title, colours, colors, addValueToLabel, updateStyles, toHtml)

{-| This module comprises tools to create and modify a model of the data, labels and styling, and then the function `toHtml` renders the model using one of the provided views.

# Chart constructors
@docs hBar, vBar, pie, lChart

# Customisers
@docs title, colours, colors, addValueToLabel, updateStyles

# Rendering
@docs toHtml
-}

import Html exposing (Html, h3, div, span, text)
import Html.Attributes exposing (style)

import List exposing (map, map2, length, filter, maximum, foldl, indexedMap)
import Dict exposing (Dict, update, get)

import Svg exposing (svg, circle)
import Svg.Attributes exposing (viewBox, r, cx, cy, width, height, stroke, strokeDashoffset, strokeDasharray, preserveAspectRatio)

import ChartModel exposing (..)
import LineChart exposing (..)

-- MODEL

-- API

{-| The horizontal bar chart results in a set of bars, one above the other, of lengths in proportion to the value. A label with the data value is printed in each bar.

    hBar vals labels
        |> title "My Chart"
        |> toHtml
-}
hBar : List Float -> List String -> Model
hBar ds ls =
    chartInit ds ls BarHorizontal
        -- |> title cTitle
        |> normalise
        |> addValueToLabel
        |> updateStyles "chart-container"
            [ ( "display", "block" )
            , ( "font", "10px sans-serif" )
            , ( "color", "white" )
            ]
        |> updateStyles "chart-elements"
            [ ( "background-color","steelblue" )
            , ( "padding", "3px" )
            , ( "margin", "1px" )
            , ( "text-align", "right" )
            ]
        |> updateStyles "legend-labels"
            [ ( "display", "block" )
            -- , ( "max-width", "100%" )
            ]

{-| The vertical bar chart results in a set of bars of lengths in proportion to the value. A label is printed below each bar.

    vBar vals labels
        |> title "My Chart"
        |> toHtml
-}
vBar : List Float -> List String -> Model
vBar ds ls =
    chartInit ds ls BarVertical
        |> normalise
        |> updateStyles "chart-container"
            [ ( "flex-direction", "column" )
            ]
        |> updateStyles "chart"
            [ ( "display", "flex" )
            , ( "justify-content", "center" )
            , ( "align-items", "flex-end" )
            , ( "height", "300px" )
            ]
        |> updateStyles "chart-elements"
            [ ( "background-color","steelblue" )
            , ( "padding", "3px" )
            , ( "margin", "1px" )
            , ( "width", "30px" )
            ]
        |> updateStyles "legend"
            [ ( "align-self", "center" )
            , ( "height", "70px" )
            ]
        |> updateStyles "legend-labels"
            [ ( "width", "100px" )
            , ( "text-align", "right" )
            , ( "overflow", "hidden" )
            , ( "white-space", "nowrap" )
            , ( "text-overflow", "ellipsis" )
            ]

{-| The pie chart results in a circle cut into coloured segments of size proportional to the data value.

    pie vals labels
        |> toHtml
-}
pie : List Float -> List String -> Model
pie ds ls =
    chartInit ds ls Pie
        |> toPercent
        -- |> updateStyles "container"
        |> updateStyles "chart-container"
            [ ( "justify-content", "center" )
            , ( "align-items", "center" )
            , ( "flex-wrap", "wrap" )
            ]
        |> updateStyles "chart"
            [ ( "height", "200px" )
            , ( "transform", "rotate(-90deg)" )
            , ( "background", "grey" )
            , ( "border-radius", "50%" )
            ]
        |> updateStyles "chart-elements"
            [ ( "fill-opacity", "0" )
            , ( "stroke-width", "32" )
            ]
        |> updateStyles "legend"
            [ ( "flex-direction", "column" )
            , ( "justify-content", "center" )
            , ( "padding-left", "15px" )
            , ( "flex-basis", "67%" )
            , ( "flex-grow", "2" )
            , ( "max-width", "100%")
            ]
        |> updateStyles "legend-labels"
            [ ( "white-space", "nowrap" )
            , ( "overflow", "hidden" )
            , ( "text-overflow", "ellipsis" )
            ]

{-| The line chart is useful for time series, or other data where the values relate to each other in some way.

    lChart vals labels
        |> toHtml
-}
lChart : List Float -> List String -> Model
lChart ds ls =
    chartInit ds ls Line
        |> updateStyles "chart-container"
            [ ( "justify-content", "center" ) ]

-- UPDATE

{-| title adds a title to the model.

    -- e.g. build a chart from scratch
    chartInit vs ls BarHorizontal
        |> title "This will be the title"
        |> toHtml
-}
title : String -> Model -> Model
title newTitle model =
     { model | title = newTitle }

{-| colours replaces the default colours. Bar charts use just one colour, which will be the head of the list provided.

    vChart vs ls
        |> colours ["steelblue"]
        |> toHtml

    pie vs ls
        |> colours ["steelblue", "#96A65B", "#D9A679", "#593F27", "#A63D33"]
        |> toHtml
-}
colours : List String -> Model -> Model
colours newColours model =
    case newColours of
        [] -> model
        (c :: cs) ->
            case model.chartType of
                Pie -> { model | colours = (c :: cs) }
                otherwise ->
                    updateStyles "chart" [ ( "background-color", c ) ] model

{-| colors supports alternative spelling of colours
-}
colors : List String -> Model -> Model
colors = colours

{-| addValueToLabel adds the data value of each item to the data label. This is applied by default in hBar.

    vBar vs ls "Title"
        |> addValueToLabel
        |> toHtml
-}
addValueToLabel : Model -> Model
addValueToLabel model =
    { model |
        items = map (\item -> { item | label = item.label ++ " " ++ toString item.value }) model.items
    }

{-| updateStyles replaces styles for a specified part of the chart. Charts have the following div structure

    .container
        .title
        .chart-container
            .chart      (container for the bars or pie segments)
                .chart-elements
            .legend     (also for the label container in a vertical bar chart)
                .legend-labels

    vChart vs ls
        |> updateStyles "chart" [ ( "color", "black" ) ]
        |> toHtml
-}
updateStyles : String -> List Style -> Model -> Model
updateStyles selector lst model =
    { model | styles =
        -- update selector (Maybe.map <| \curr -> foldl changeStyles curr lst) model.styles }
        update selector (Maybe.map <| flip (foldl changeStyles) lst) model.styles }


-- NOT exported

normalise : Model -> Model
normalise model =
    case maximum (map .value model.items) of
        Nothing -> model
        Just maxD ->
            { model |
                items = map (\item -> { item | normValue = item.value / maxD * 100 }) model.items
            }

toPercent : Model -> Model
toPercent model =
    let tot = List.sum (map .value model.items)
    in
        { model |
            items = map (\item -> { item | normValue = item.value / tot * 100 }) model.items
        }

-- removes existing style setting (if any) and inserts new one
changeStyles : Style -> List Style -> List Style
changeStyles (attr, val) styles =
    (attr, val) :: (filter (\(t,_) -> t /= attr) styles)


-- VIEW

{-| toHtml is called last, and causes the chart data to be rendered to html.

    hBar vs ls
        |> toHtml
-}

toHtml : Model -> Html a
toHtml model =
    let get' sel = Maybe.withDefault [] (get sel model.styles)
    in
    div [ style <| get' "container" ]
        [ h3 [ style <| get' "title" ] [ text model.title ]
        , div [ style <| get' "chart-container" ] <|
            -- chart-elements, axis, legend-labels,...
            case model.chartType of
                BarHorizontal -> viewBarHorizontal model
                BarVertical -> viewBarVertical model
                Pie -> viewPie model
                Line -> viewLine model
        ]

viewBarHorizontal : Model -> List (Html a)
viewBarHorizontal model =
    let
        get' sel = Maybe.withDefault [] (get sel model.styles)
        colour = Maybe.withDefault "steelblue" (List.head model.colours)
        elements =
            map
                (\{normValue, label} ->
                    div [ style <|
                            [ ( "width", toString normValue ++ "%" )
                            , ( "background-color", colour )
                            ] ++ get' "chart-elements"
                        ]
                        [ span [style <| get' "legend-labels" ]
                            [ text label ]
                        ]
                )
                model.items
    in
    elements

-- V E R T I C A L
viewBarVertical : Model -> List (Html a)
viewBarVertical model =
    let
        get' sel = Maybe.withDefault [] (get sel model.styles)

        elements =
            map
                (\{normValue} -> div [ style <| ( "height", toString normValue ++ "%" ) :: get' "chart-elements" ] [  ] )
                model.items

        rotateLabel : Int -> Int -> Style
        rotateLabel lenData idx =
            let
                labelWidth = 60
                offset =
                    case lenData % 2 == 0 of
                        True ->  (lenData // 2 - idx - 1) * labelWidth + 20        -- 6 chart-elements, 2&3 are the middle
                        False -> (lenData // 2 - idx) * labelWidth - 10      -- 5 chart-elements, 2 is the middle
            in ( "transform", "translateX( "++(toString offset)++"px) translateY(30px) rotate(-45deg)" )

        labels =
            indexedMap
                ( \idx item ->
                    div
                        [ style <| (rotateLabel (length model.items) idx) :: get' "legend-labels" ]
                        [ text (.label item) ]
                ) model.items
    in
    [ div [ style <| get' "chart" ] elements
    , div [ style <| get' "legend" ] labels
    ]

-- P I E   V I E W
viewPie : Model -> List (Html a)
viewPie model =
    let
        elem off ang col =
            circle
                [ r "16"
                , cx "16"        -- translation x-axis
                , cy "16"
                , stroke col
                , strokeDashoffset (toString off)
                , strokeDasharray <| (toString ang) ++ " 100"
                , style <| get' "chart-elements"
                ] []
        go val (accOff, cols, accElems) =
            case cols of
                (c::cs) ->
                    ( accOff - val.normValue
                    , if List.isEmpty cs then model.colours else cs
                    , elem accOff val.normValue c :: accElems
                    )
                [] -> (accOff, cols, accElems)    -- redundant

        (_, _, elems) = foldl go (0, model.colours, []) model.items

        legend items =
            List.map2
                ( \{label} col ->
                    div [ style <| get' "legend-labels" ]
                        [ span
                            [style
                                [ ( "background-color", col)
                                , ( "display", "inline-block" )
                                , ( "height", "20px" )
                                , ( "width", "20px" )
                                , ( "margin-right", "5px" )
                                ]
                            ] [ text " " ]
                         , Html.text label
                         ]
                )
                items model.colours

        get' sel = Maybe.withDefault [] (get sel model.styles)
    in
        [ Svg.svg                       -- chart
            [ style (get' "chart" )
            , viewBox "0 0 32 32"
            , preserveAspectRatio "xMidYMid slice"
            ] elems
        , div                           -- legend
            [ style <| get' "legend" ]
            (legend model.items)
        ]

viewLine =
    LineChart.viewLine
