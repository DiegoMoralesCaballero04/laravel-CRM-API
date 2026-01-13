<?php

namespace App\CRM\Properties\Controllers;

use App\CRM\Properties\Queries\AvailableForOperationsQuery;
use App\CRM\Properties\Requests\AvailableForOperationsRequest;
use App\CRM\Properties\Resources\AvailablePropertyResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;

class AvailablePropertiesController extends Controller
{
    public function index(AvailableForOperationsRequest $request): JsonResponse
    {
        $filters = $request->validated();
        $user = $request->user();

        $query = (new AvailableForOperationsQuery($filters, $user))->build();

        $paginator = $query->paginate(
            perPage: (int) $filters['per_page'],
            page: (int) $filters['page']
        );

        return response()->json([
            'data' => AvailablePropertyResource::collection($paginator->items()),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
            ],
        ]);
    }
}
