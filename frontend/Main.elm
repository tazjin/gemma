-- Copyright (C) 2016-2017  Vincent Ambo <mail@tazj.in>
--
-- This file is part of Gemma.
--
-- Gemma is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.


module Main exposing (..)

import Html exposing (Html, text, div, span)
import Html.Attributes exposing (style)
import Json.Decode exposing (..)
import Http
import Time


--  Material design imports

import Material
import Material.Card as Card
import Material.Color as Color
import Material.Grid exposing (grid, cell, size, Device(..))
import Material.Layout as Layout
import Material.Scheme as Scheme
import Material.Options as Options
import Material.Elevation as Elevation
import Material.Button as Button


-- API interface to Gemma


type alias Task =
    { name : String
    , description : Maybe String
    , remaining : Int
    }


emptyStringFilter s =
    if s == "" then
        Nothing
    else
        Just s


decodeEmptyString : Decoder (Maybe String)
decodeEmptyString =
    map emptyStringFilter string


decodeTask : Decoder Task
decodeTask =
    map3 Task
        (field "name" string)
        (field "description" decodeEmptyString)
        (field "remaining" int)


loadTasks : Cmd Msg
loadTasks =
    let
        request =
            Http.get "/tasks" (list decodeTask)
    in
        Http.send NewTasks request


completeTask : Task -> Cmd Msg
completeTask task =
    let
        request =
            Http.getString
                (String.concat
                    [ "/complete?task="
                    , task.name
                    ]
                )
    in
        Http.send (\_ -> LoadTasks) request



-- Elm architecture implementation


type Msg
    = None
    | LoadTasks
    | NewTasks (Result Http.Error (List Task))
    | Mdl (Material.Msg Msg)
    | Complete Task


type alias Model =
    { tasks : List Task
    , error : Maybe String
    , mdl : Material.Model
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadTasks ->
            ( model, loadTasks )

        Complete task ->
            ( model, completeTask task )

        NewTasks (Ok tasks) ->
            ( { model | tasks = tasks, error = Nothing }, Cmd.none )

        NewTasks (Err err) ->
            ( { model | error = Just (toString err) }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- View implementation


white =
    Color.text Color.white


taskColor : Task -> Color.Hue
taskColor task =
    if task.remaining > 2 then
        Color.Green
    else if task.remaining < 0 then
        Color.Red
    else
        Color.Yellow


within : Task -> String
within task =
    if task.remaining < 0 then
        "This task is overdue!"
    else if task.remaining > 2 then
        String.concat
            [ "Relax, this task has "
            , toString task.remaining
            , " days left before it is due."
            ]
    else
        String.concat
            [ "This task should be completed within "
            , toString task.remaining
            , " days. Consider doing it now!"
            ]


renderTask : Model -> Task -> Html Msg
renderTask model task =
    Card.view
        [ Color.background (Color.color (taskColor task) Color.S800)
        , Elevation.e3
        ]
        [ Card.title [] [ Card.head [ white ] [ text task.name ] ]
        , Card.text [ white ]
            [ text (Maybe.withDefault "" task.description)
            , Html.br [] []
            , text (within task)
            ]
        , Card.actions
            [ Card.border ]
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ white, Button.ripple, Button.accent, Options.onClick (Complete task) ]
                [ text "Completed" ]
            ]
        ]


gemmaView : Model -> Html Msg
gemmaView model =
    grid []
        (List.map (\t -> cell [ size All 4 ] [ renderTask model t ])
            model.tasks
        )


view : Model -> Html Msg
view model =
    gemmaView model |> Scheme.top



-- subscriptions : Model -> Sub Msg


subscriptions model =
    Sub.batch
        [ Material.subscriptions Mdl model
        , Time.every (15 * Time.second) (\_ -> LoadTasks)
        ]


main : Program Never Model Msg
main =
    let
        model =
            { tasks = []
            , error = Nothing
            , mdl = Material.model
            }
    in
        Html.program
            { init = ( model, Cmd.batch [ loadTasks, Material.init Mdl ] )
            , view = view
            , update = update
            , subscriptions = subscriptions
            }
