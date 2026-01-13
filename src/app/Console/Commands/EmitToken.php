<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class EmitToken extends Command
{
    protected $signature = 'token:emit {email}';
    protected $description = 'Emite un token personal para pruebas';

    public function handle(): int
    {
        $email = (string) $this->argument('email');
        $user = User::where('email', $email)->first();

        if (!$user) {
            $this->error('No existe ese usuario');
            return self::FAILURE;
        }

        $token = $user->createToken('demo')->plainTextToken;
        $this->line($token);

        return self::SUCCESS;
    }
}
