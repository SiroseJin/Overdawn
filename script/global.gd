extends Node

var PlayerBody :CharacterBody2D
var PlayerWeaponEquip: bool

var gameStarted: bool 

var playerAlive: bool
var playerDamageZone: Area2D
var playerDamageAmount: int
var playerHitbox: Area2D

var batDamageZone: Area2D
var batDamageAmmount: int

var frogDamageZone: Area2D
var frogDamageAmmount: int

var witchDamageZone: Area2D
var witchDamageAmmount: int

var necroDamageZone: Area2D
var necroDamageAmmount: int

var current_wave: int
var moving_to_next_wave: bool
