<?php

use Illuminate\Support\Facades\Route;
use App\CRM\Properties\Controllers\AvailablePropertiesController;

Route::middleware('auth:sanctum')->get('/properties/available-for-operations', [AvailablePropertiesController::class, 'index']);
